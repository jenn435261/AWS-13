package packages

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

// signingServer returns a package Server with a MapDir holding the given file
// plus a signing key, and the signing key's public half (the trusted root).
func signingServer(t *testing.T, name string, data []byte) (*Server, ed25519.PublicKey) {
	t.Helper()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, name), data, 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	s := New(Config{MapDir: dir})
	s.WithSigningKey(priv)
	return s, pub
}

func TestManifestSignAndVerify(t *testing.T) {
	data := []byte("pmtiles-bytes-here")
	s, root := signingServer(t, "bay.pmtiles", data)

	m, err := s.BuildManifest(1_700_000_000_000)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if len(m.Entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(m.Entries))
	}
	wantSum := sha256.Sum256(data)
	if m.Entries[0].SHA256 != hex.EncodeToString(wantSum[:]) {
		t.Fatalf("entry sha256 = %s, want %s", m.Entries[0].SHA256, hex.EncodeToString(wantSum[:]))
	}

	sm, err := SignManifest(m, s.signingKey)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}

	// Verifies against the trusted root.
	verified, err := VerifyManifest(sm, root)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if len(verified.Entries) != 1 {
		t.Fatalf("verified entries = %d", len(verified.Entries))
	}

	// Fails against a different (untrusted) root.
	otherPub, _, _ := ed25519.GenerateKey(nil)
	if _, err := VerifyManifest(sm, otherPub); err != ErrUntrustedKey {
		t.Fatalf("expected ErrUntrustedKey, got %v", err)
	}

	// Fails when the manifest body is tampered after signing.
	tampered := sm
	tampered.Manifest.Entries = append([]ManifestEntry(nil), sm.Manifest.Entries...)
	tampered.Manifest.Entries[0].SHA256 = hex.EncodeToString(make([]byte, 32))
	if _, err := VerifyManifest(tampered, root); err != ErrBadSignature {
		t.Fatalf("expected ErrBadSignature on tamper, got %v", err)
	}
}

// TestCanonicalBytesNoHTMLEscape guards the cross-language canonicalization
// contract: Go must NOT HTML-escape '<', '>' or '&' (the json.Marshal default),
// because the Dart client rebuilds the same preimage with jsonEncode, which
// does not escape those runes. An entry whose name/path contains one of these
// characters (a literal '&' is ordinary in a filename) must still produce the
// literal rune in the canonical bytes so the detached Ed25519 signature
// verifies on device instead of reporting a false badSignature.
func TestCanonicalBytesNoHTMLEscape(t *testing.T) {
	m := Manifest{
		Version:     1,
		GeneratedMs: 1_700_000_000_000,
		Entries: []ManifestEntry{
			{
				Kind:      "map",
				Name:      "rescue & relief <east>.pmtiles",
				Path:      "/node/v1/map/rescue & relief <east>.pmtiles",
				SizeBytes: 3,
				SHA256:    hex.EncodeToString(make([]byte, 32)),
			},
		},
	}
	canonical, err := m.CanonicalBytes()
	if err != nil {
		t.Fatalf("canonical: %v", err)
	}
	s := string(canonical)
	for _, raw := range []string{"&", "<", ">"} {
		if !bytes.Contains(canonical, []byte(raw)) {
			t.Fatalf("canonical bytes missing literal %q: %s", raw, s)
		}
	}
	for _, escaped := range []string{`\u0026`, `\u003c`, `\u003e`} {
		if bytes.Contains(canonical, []byte(escaped)) {
			t.Fatalf("canonical bytes contain HTML-escaped %q (must match Dart jsonEncode): %s", escaped, s)
		}
	}
	// Encode must not leave a trailing newline in the signed preimage.
	if bytes.HasSuffix(canonical, []byte("\n")) {
		t.Fatalf("canonical bytes end with a newline: %q", s)
	}
}

// TestManifestSignVerifyWithSpecialChars signs and verifies a manifest whose
// name/path contain '&', '<' and '>' to prove the full round-trip holds for
// the characters Go's default json.Marshal would have escaped.
func TestManifestSignVerifyWithSpecialChars(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	m := Manifest{
		Version:     1,
		GeneratedMs: 1_700_000_000_000,
		Entries: []ManifestEntry{
			{
				Kind:      "map",
				Name:      "a & b <c>.pmtiles",
				Path:      "/node/v1/map/a & b <c>.pmtiles",
				SizeBytes: 7,
				SHA256:    hex.EncodeToString(make([]byte, 32)),
			},
		},
	}
	sm, err := SignManifest(m, priv)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if _, err := VerifyManifest(sm, pub); err != nil {
		t.Fatalf("verify manifest with special chars: %v", err)
	}
}

func TestManifestEndpointServesSigned(t *testing.T) {
	data := []byte("1234567890")
	s, root := signingServer(t, "region.pmtiles", data)
	ts := newServerWith(t, s)

	resp, err := http.Get(ts.URL + "/node/v1/manifest")
	if err != nil {
		t.Fatalf("get manifest: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("manifest status = %d", resp.StatusCode)
	}
	var sm SignedManifest
	if err := json.NewDecoder(resp.Body).Decode(&sm); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if _, err := VerifyManifest(sm, root); err != nil {
		t.Fatalf("served manifest failed verification: %v", err)
	}
}

func TestManifestEndpoint503WithoutKey(t *testing.T) {
	dir := t.TempDir()
	_ = os.WriteFile(filepath.Join(dir, "x.pmtiles"), []byte("y"), 0o644)
	ts := newServer(t, Config{MapDir: dir}) // no signing key
	resp, err := http.Get(ts.URL + "/node/v1/manifest")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 without signing key, got %d", resp.StatusCode)
	}
}

// TestRangeResumeDownload simulates an interrupted download that resumes from
// the byte offset it already has, then verifies the reassembled bytes against
// the signed manifest's checksum. This is the exact flow a client uses for a
// large PMTiles map on a flaky link.
func TestRangeResumeDownload(t *testing.T) {
	// 300 bytes of predictable content.
	data := make([]byte, 300)
	for i := range data {
		data[i] = byte(i % 251)
	}
	s, root := signingServer(t, "big.pmtiles", data)
	ts := newServerWith(t, s)

	// 1. Fetch and verify the manifest to learn the expected checksum.
	mresp, err := http.Get(ts.URL + "/node/v1/manifest")
	if err != nil {
		t.Fatalf("manifest: %v", err)
	}
	var sm SignedManifest
	_ = json.NewDecoder(mresp.Body).Decode(&sm)
	mresp.Body.Close()
	m, err := VerifyManifest(sm, root)
	if err != nil {
		t.Fatalf("verify manifest: %v", err)
	}
	entry := m.Entries[0]

	url := ts.URL + entry.Path

	// 2. Download the first 100 bytes and "crash".
	req1, _ := http.NewRequest(http.MethodGet, url, nil)
	req1.Header.Set("Range", "bytes=0-99")
	r1, err := http.DefaultClient.Do(req1)
	if err != nil {
		t.Fatalf("part1: %v", err)
	}
	if r1.StatusCode != http.StatusPartialContent {
		t.Fatalf("part1 status = %d, want 206", r1.StatusCode)
	}
	if ar := r1.Header.Get("Accept-Ranges"); ar != "bytes" {
		t.Fatalf("Accept-Ranges = %q, want bytes", ar)
	}
	part1, _ := io.ReadAll(r1.Body)
	r1.Body.Close()
	if len(part1) != 100 {
		t.Fatalf("part1 len = %d, want 100", len(part1))
	}

	// 3. Resume from byte 100 to the end.
	req2, _ := http.NewRequest(http.MethodGet, url, nil)
	req2.Header.Set("Range", "bytes=100-")
	r2, err := http.DefaultClient.Do(req2)
	if err != nil {
		t.Fatalf("part2: %v", err)
	}
	if r2.StatusCode != http.StatusPartialContent {
		t.Fatalf("part2 status = %d, want 206", r2.StatusCode)
	}
	part2, _ := io.ReadAll(r2.Body)
	r2.Body.Close()

	// 4. Reassemble and verify against the manifest checksum.
	whole := append(append([]byte{}, part1...), part2...)
	if !bytes.Equal(whole, data) {
		t.Fatalf("reassembled bytes differ from source (len %d)", len(whole))
	}
	sum := sha256.Sum256(whole)
	if hex.EncodeToString(sum[:]) != entry.SHA256 {
		t.Fatalf("checksum mismatch: resumed download does not match manifest")
	}
}

// newServerWith mounts an already-configured Server (with a signing key) on a
// test HTTP server.
func newServerWith(t *testing.T, s *Server) *httptest.Server {
	t.Helper()
	mux := http.NewServeMux()
	s.Register(mux)
	ts := httptest.NewServer(mux)
	t.Cleanup(ts.Close)
	return ts
}
