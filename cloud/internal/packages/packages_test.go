package packages

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func writePack(t *testing.T, dir, name string, size int) []byte {
	t.Helper()
	data := make([]byte, size)
	for i := range data {
		data[i] = byte(i % 251)
	}
	if err := os.WriteFile(filepath.Join(dir, name), data, 0o644); err != nil {
		t.Fatalf("write pack: %v", err)
	}
	return data
}

func newPackServer(t *testing.T) (*Server, ed25519.PrivateKey, map[string][]byte) {
	t.Helper()
	dir := t.TempDir()
	files := map[string][]byte{
		"bay.pmtiles":  writePack(t, dir, "bay.pmtiles", 5000),
		"firstaid.json": writePack(t, dir, "firstaid.json", 300),
	}
	seed := make([]byte, ed25519.SeedSize)
	seed[0] = 7
	priv := ed25519.NewKeyFromSeed(seed)
	s := New(Config{PackDir: dir})
	s.WithSigningKey(priv)
	return s, priv, files
}

func TestCloudManifestSignVerify(t *testing.T) {
	s, priv, files := newPackServer(t)
	m, err := s.BuildManifest(123)
	if err != nil {
		t.Fatalf("build manifest: %v", err)
	}
	if len(m.Entries) != 2 {
		t.Fatalf("got %d entries, want 2", len(m.Entries))
	}
	sm, err := SignManifest(m, priv)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	// Verifies against the correct root.
	pub := priv.Public().(ed25519.PublicKey)
	if _, verr := VerifyManifest(sm, pub); verr != nil {
		t.Fatalf("verify: %v", verr)
	}
	// Each entry's sha256 matches the actual bytes.
	for _, e := range m.Entries {
		want := sha256.Sum256(files[e.Name])
		if e.SHA256 != hex.EncodeToString(want[:]) {
			t.Fatalf("checksum mismatch for %s", e.Name)
		}
	}
	// Wrong root fails closed.
	otherPub, _, _ := ed25519.GenerateKey(nil)
	if _, verr := VerifyManifest(sm, otherPub); verr != ErrUntrustedKey {
		t.Fatalf("wrong root: got %v, want ErrUntrustedKey", verr)
	}
	// Tampered manifest fails closed.
	tampered := sm
	tampered.Manifest.Entries[0].SHA256 = "deadbeef"
	if _, verr := VerifyManifest(tampered, pub); verr != ErrBadSignature {
		t.Fatalf("tamper: got %v, want ErrBadSignature", verr)
	}
}

func TestCloudManifestNoHTMLEscape(t *testing.T) {
	// A name with & < > must appear literally (match the Dart jsonEncode output).
	m := Manifest{Version: 1, GeneratedMs: 1, Entries: []ManifestEntry{
		{Kind: "map", Name: "a&b<c>.pmtiles", Path: "/v1/packages/a&b<c>.pmtiles", SizeBytes: 1, SHA256: "ab"},
	}}
	b, err := m.CanonicalBytes()
	if err != nil {
		t.Fatalf("canonical: %v", err)
	}
	s := string(b)
	for _, esc := range []string{`\u0026`, `\u003c`, `\u003e`} {
		if contains(s, esc) {
			t.Fatalf("canonical bytes HTML-escaped %q: %s", esc, s)
		}
	}
	if s[len(s)-1] == '\n' {
		t.Fatal("canonical bytes must not have a trailing newline")
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

func TestCloudManifestServed(t *testing.T) {
	s, priv, _ := newPackServer(t)
	mux := http.NewServeMux()
	s.Register(mux, nil)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/v1/packages/manifest")
	if err != nil {
		t.Fatalf("get manifest: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		t.Fatalf("status %d", resp.StatusCode)
	}
	var sm SignedManifest
	if derr := json.NewDecoder(resp.Body).Decode(&sm); derr != nil {
		t.Fatalf("decode: %v", derr)
	}
	if sm.Algorithm != "ed25519" {
		t.Fatalf("algorithm = %q", sm.Algorithm)
	}
	pub := priv.Public().(ed25519.PublicKey)
	if sm.PublicKey != hex.EncodeToString(pub) {
		t.Fatal("public key mismatch")
	}
	if _, verr := VerifyManifest(sm, pub); verr != nil {
		t.Fatalf("served manifest does not verify: %v", verr)
	}
}

func TestCloudManifest503WithoutKey(t *testing.T) {
	dir := t.TempDir()
	writePack(t, dir, "bay.pmtiles", 100)
	s := New(Config{PackDir: dir}) // no signing key
	mux := http.NewServeMux()
	s.Register(mux, nil)
	srv := httptest.NewServer(mux)
	defer srv.Close()
	resp, err := http.Get(srv.URL + "/v1/packages/manifest")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503 (refuse unsigned manifest)", resp.StatusCode)
	}
}

func TestCloudRangeResumeDownload(t *testing.T) {
	s, priv, files := newPackServer(t)
	mux := http.NewServeMux()
	s.Register(mux, nil)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	full := files["bay.pmtiles"]

	// Fetch in two Range parts and reassemble.
	part := func(start, end int) []byte {
		req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/packages/bay.pmtiles", nil)
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", start, end))
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("range get: %v", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusPartialContent {
			t.Fatalf("status = %d, want 206", resp.StatusCode)
		}
		b := make([]byte, 0)
		buf := make([]byte, 4096)
		for {
			n, rerr := resp.Body.Read(buf)
			b = append(b, buf[:n]...)
			if rerr != nil {
				break
			}
		}
		return b
	}
	mid := len(full) / 2
	first := part(0, mid-1)
	second := part(mid, len(full)-1)
	got := append(append([]byte{}, first...), second...)
	if len(got) != len(full) {
		t.Fatalf("reassembled %d bytes, want %d", len(got), len(full))
	}
	gotSum := sha256.Sum256(got)
	wantSum := sha256.Sum256(full)
	if gotSum != wantSum {
		t.Fatal("reassembled range download checksum mismatch")
	}

	// And it matches the signed manifest entry.
	m, _ := s.BuildManifest(1)
	sm, _ := SignManifest(m, priv)
	vm, verr := VerifyManifest(sm, priv.Public().(ed25519.PublicKey))
	if verr != nil {
		t.Fatalf("verify: %v", verr)
	}
	var entrySum string
	for _, e := range vm.Entries {
		if e.Name == "bay.pmtiles" {
			entrySum = e.SHA256
		}
	}
	if entrySum != hex.EncodeToString(wantSum[:]) {
		t.Fatal("range download does not match signed manifest checksum")
	}
}
