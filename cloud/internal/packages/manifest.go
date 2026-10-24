package packages

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"sort"
)

// ManifestEntry is one artifact's integrity record: catalog metadata plus the
// SHA-256 a client verifies after download. The JSON shape and field order are
// IDENTICAL to node/internal/packages.ManifestEntry and the Dart
// PackageManifest, so the same signed-manifest verifier works for cloud packs.
type ManifestEntry struct {
	Kind      string `json:"kind"`
	Name      string `json:"name"`
	Path      string `json:"path"`
	SizeBytes int64  `json:"size_bytes"`
	SHA256    string `json:"sha256"`
}

// Manifest is the canonical, signable description of everything the cloud
// serves. Signed with a detached Ed25519 signature; a client verifies against a
// trusted root (the cloud packages key), then checks each file's SHA-256.
type Manifest struct {
	Version     int             `json:"version"`
	GeneratedMs int64           `json:"generated_ms"`
	Entries     []ManifestEntry `json:"entries"`
}

// SignedManifest is served at /v1/packages/manifest.
type SignedManifest struct {
	Manifest  Manifest `json:"manifest"`
	PublicKey string   `json:"public_key"`
	Signature string   `json:"signature"`
	Algorithm string   `json:"algorithm"`
}

// CanonicalBytes returns the deterministic signable bytes. It MUST match
// node/internal/packages.Manifest.CanonicalBytes and the Dart
// PackageManifest.canonicalBytes: entries sorted by (kind, name), compact JSON
// with HTML escaping DISABLED and no trailing newline.
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
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(canonical); err != nil {
		return nil, err
	}
	return bytes.TrimRight(buf.Bytes(), "\n"), nil
}

// BuildManifest computes the signable manifest for the pack directory, reading
// each file to compute its SHA-256. Unreadable files are skipped.
func (s *Server) BuildManifest(generatedMs int64) (Manifest, error) {
	entries := make([]ManifestEntry, 0)
	for _, it := range s.Catalog() {
		file := joinSafe(s.cfg.PackDir, it.Name)
		if file == "" {
			continue
		}
		sum, size, err := sha256File(file)
		if err != nil {
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
		return SignedManifest{}, errors.New("cloud packages: invalid signing key size")
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

// ErrUntrustedKey / ErrBadSignature mirror the node verifier's errors.
var (
	ErrUntrustedKey = errors.New("cloud packages: manifest signed by an untrusted key")
	ErrBadSignature = errors.New("cloud packages: manifest signature does not verify")
)

// VerifyManifest checks a SignedManifest fail-closed against trustedRoot. It is
// here mainly for tests + parity with the node package; the real verifier is the
// Dart client.
func VerifyManifest(sm SignedManifest, trustedRoot ed25519.PublicKey) (Manifest, error) {
	if sm.Algorithm != "ed25519" {
		return Manifest{}, errors.New("cloud packages: unsupported manifest algorithm")
	}
	pub, err := hex.DecodeString(sm.PublicKey)
	if err != nil || len(pub) != ed25519.PublicKeySize {
		return Manifest{}, errors.New("cloud packages: bad manifest public key")
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

func (s *Server) handleManifest(w http.ResponseWriter, r *http.Request) {
	if len(s.signingKey) != ed25519.PrivateKeySize {
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

// sha256File streams a file and returns its lowercase-hex SHA-256 and size.
func sha256File(path string) (string, int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer f.Close()
	h := sha256.New()
	n, err := io.Copy(h, f)
	if err != nil {
		return "", 0, err
	}
	return hex.EncodeToString(h.Sum(nil)), n, nil
}
