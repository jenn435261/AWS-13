package packages

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"sort"
)

// ManifestEntry is one artifact's integrity record in a signed manifest: the
// catalog metadata plus the SHA-256 checksum a client verifies after download.
type ManifestEntry struct {
	Kind      string `json:"kind"`
	Name      string `json:"name"`
	Path      string `json:"path"`
	SizeBytes int64  `json:"size_bytes"`
	SHA256    string `json:"sha256"` // lowercase hex of the file's SHA-256
}

// Manifest is the canonical, signable description of everything the node
// serves. It is signed with a detached signature (see SignedManifest); a client
// verifies the signature against a trusted root public key, then checks each
// downloaded file's SHA-256 against the matching entry before trusting it.
type Manifest struct {
	Version    int             `json:"version"`
	GeneratedMs int64          `json:"generated_ms"`
	Entries    []ManifestEntry `json:"entries"`
}

// SignedManifest is what the node serves at /node/v1/manifest: the manifest,
// a detached Ed25519 signature over its canonical bytes, and the public key
// that produced it. A client that trusts the key (it must equal a configured
// trusted root) can verify the signature without any transport trust, then use
// the per-entry checksums to validate downloads fetched over any channel
// (including a resumed Range download).
type SignedManifest struct {
	Manifest  Manifest `json:"manifest"`
	PublicKey string   `json:"public_key"` // lowercase hex ed25519 public key
	Signature string   `json:"signature"`  // lowercase hex detached signature
	// Algorithm names the scheme so clients can reject anything they do not
	// implement. Only "ed25519" over canonical JSON is defined today.
	Algorithm string `json:"algorithm"`
}

// CanonicalBytes returns the deterministic bytes that are signed and verified.
// Entries are sorted (kind, then name) so the same filesystem state always
// yields the same preimage regardless of directory iteration order. The
// GeneratedMs field is included so each publication is distinct but it does not
// affect checksum verification.
func (m Manifest) CanonicalBytes() ([]byte, error) {
	sorted := make([]ManifestEntry, len(m.Entries))
	copy(sorted, m.Entries)
	sort.SliceStable(sorted, func(i, j int) bool {
		if sorted[i].Kind != sorted[j].Kind {
			return sorted[i].Kind < sorted[j].Kind
		}
		return sorted[i].Name < sorted[j].Name
	})
	canonical := Manifest{Version: m.Version, GeneratedMs: m.GeneratedMs, Entries: sorted}
	// encoding/json marshals struct fields in declaration order, so field order
	// is stable. We MUST disable HTML escaping: json.Marshal escapes '<', '>'
	// and '&' to \u003c/\u003e/\u0026, but the Dart client rebuilds this
	// preimage with jsonEncode, which does NOT escape those runes. Leaving the
	// default on would make the two canonical byte strings diverge (and the
	// signature fail as badSignature) for any entry name/path containing one
	// of those characters (e.g. a literal '&' in a filename). SetEscapeHTML
	// (false) makes Go match Dart. Encode appends a trailing newline, so trim
	// it to keep the preimage identical to Dart's jsonEncode output.
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(canonical); err != nil {
		return nil, err
	}
	return bytes.TrimRight(buf.Bytes(), "\n"), nil
}

// BuildManifest computes the signable manifest for the configured directories,
// reading each file to compute its SHA-256. Missing or unreadable files are
// skipped (the catalog already reflects what is actually present). generatedMs
// is stamped into the manifest for freshness.
func (s *Server) BuildManifest(generatedMs int64) (Manifest, error) {
	cat := s.Catalog()
	entries := make([]ManifestEntry, 0, len(cat))
	for _, it := range cat {
		file := s.fileForItem(it)
		if file == "" {
			continue
		}
		sum, size, err := sha256File(file)
		if err != nil {
			// A file listed by the catalog but unreadable now is simply left
			// out of the manifest rather than failing the whole publication.
			continue
		}
		entries = append(entries, ManifestEntry{
			Kind:      it.Kind,
			Name:      it.Name,
			Path:      it.Path,
			SizeBytes: size,
			SHA256:    sum,
		})
	}
	return Manifest{Version: 1, GeneratedMs: generatedMs, Entries: entries}, nil
}

// SignManifest produces a SignedManifest with a detached Ed25519 signature over
// the manifest's canonical bytes.
func SignManifest(m Manifest, priv ed25519.PrivateKey) (SignedManifest, error) {
	if len(priv) != ed25519.PrivateKeySize {
		return SignedManifest{}, errors.New("packages: invalid signing key size")
	}
	canonical, err := m.CanonicalBytes()
	if err != nil {
		return SignedManifest{}, err
	}
	sig := ed25519.Sign(priv, canonical)
	pub := priv.Public().(ed25519.PublicKey)
	return SignedManifest{
		Manifest:  m,
		PublicKey: hex.EncodeToString(pub),
		Signature: hex.EncodeToString(sig),
		Algorithm: "ed25519",
	}, nil
}

// ErrUntrustedKey is returned when the manifest is signed by a key that is not
// the trusted root a client was told to expect.
var ErrUntrustedKey = errors.New("packages: manifest signed by an untrusted key")

// ErrBadSignature is returned when the detached signature does not verify.
var ErrBadSignature = errors.New("packages: manifest signature does not verify")

// VerifyManifest checks a SignedManifest fail-closed: the algorithm must be
// one we implement, the embedded public key must equal the trusted root, and
// the detached signature must verify over the manifest's canonical bytes. It
// returns the verified Manifest so callers can read its checksums with
// confidence. A client should call this before trusting any entry.
func VerifyManifest(sm SignedManifest, trustedRoot ed25519.PublicKey) (Manifest, error) {
	if sm.Algorithm != "ed25519" {
		return Manifest{}, errors.New("packages: unsupported manifest algorithm")
	}
	pub, err := hex.DecodeString(sm.PublicKey)
	if err != nil || len(pub) != ed25519.PublicKeySize {
		return Manifest{}, errors.New("packages: bad manifest public key")
	}
	if len(trustedRoot) != ed25519.PublicKeySize || !ed25519.PublicKey(pub).Equal(trustedRoot) {
		return Manifest{}, ErrUntrustedKey
	}
	sig, err := hex.DecodeString(sm.Signature)
	if err != nil || len(sig) != ed25519.SignatureSize {
		return Manifest{}, ErrBadSignature
	}
	canonical, err := sm.Manifest.CanonicalBytes()
	if err != nil {
		return Manifest{}, err
	}
	if !ed25519.Verify(pub, canonical, sig) {
		return Manifest{}, ErrBadSignature
	}
	return sm.Manifest, nil
}

// WithSigningKey installs the private key used to sign the served manifest.
// When no key is set, /node/v1/manifest is unavailable (503): the node refuses
// to serve an unsigned manifest so a client is never tricked into trusting one.
func (s *Server) WithSigningKey(priv ed25519.PrivateKey) {
	s.signingKey = priv
}

func (s *Server) handleManifest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if len(s.signingKey) != ed25519.PrivateKeySize {
		// No signing key: do not serve an unsigned manifest.
		http.Error(w, "manifest signing not configured", http.StatusServiceUnavailable)
		return
	}
	m, err := s.BuildManifest(nowMs())
	if err != nil {
		http.Error(w, "build manifest", http.StatusInternalServerError)
		return
	}
	sm, err := SignManifest(m, s.signingKey)
	if err != nil {
		http.Error(w, "sign manifest", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(sm)
}

// fileForItem maps a catalog Item back to its on-disk path, reusing the same
// safe-name/within-dir rules the serving handlers enforce.
func (s *Server) fileForItem(it Item) string {
	switch it.Kind {
	case "app":
		return pickAPK(s.cfg.APKDir)
	case "map":
		if s.cfg.MapDir == "" || !safeName(it.Name) {
			return ""
		}
		full := joinSafe(s.cfg.MapDir, it.Name)
		if full == "" {
			return ""
		}
		return full
	case "readiness":
		if s.cfg.ReadinessDir == "" || !safeName(it.Name) {
			return ""
		}
		return joinSafe(s.cfg.ReadinessDir, it.Name)
	default:
		return ""
	}
}

// sha256File streams a file and returns its lowercase-hex SHA-256 and size.
func sha256File(path string) (string, int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer f.Close()
	h := sha256.New()
	n, err := copyInto(h, f)
	if err != nil {
		return "", 0, err
	}
	return hex.EncodeToString(h.Sum(nil)), n, nil
}
