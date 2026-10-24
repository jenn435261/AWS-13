package syncserver

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/resilience-network/aws13/node/internal/cache"
)

func nodeTestServer(t *testing.T) (*Server, *httptest.Server) {
	t.Helper()
	c, err := cache.Open("")
	if err != nil {
		t.Fatalf("cache: %v", err)
	}
	s := New(c)
	mux := http.NewServeMux()
	s.Register(mux)
	return s, httptest.NewServer(mux)
}

func hashHex(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func putNodeBlob(t *testing.T, base, hash string, data []byte) *http.Response {
	t.Helper()
	req, err := http.NewRequest(http.MethodPut, base+"/node/v1/blobs/"+hash, bytes.NewReader(data))
	if err != nil {
		t.Fatalf("new put: %v", err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do put: %v", err)
	}
	return resp
}

// TestNodeBlobRoundTrip proves PUT then GET by hash returns the same bytes.
func TestNodeBlobRoundTrip(t *testing.T) {
	_, srv := nodeTestServer(t)
	defer srv.Close()

	data := []byte("opaque-node-ciphertext-xyz")
	h := hashHex(data)

	resp := putNodeBlob(t, srv.URL, h, data)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("put status = %d, want 201", resp.StatusCode)
	}

	resp2, err := http.Get(srv.URL + "/node/v1/blobs/" + h)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusOK {
		t.Fatalf("get status = %d, want 200", resp2.StatusCode)
	}
	got, _ := io.ReadAll(resp2.Body)
	if !bytes.Equal(got, data) {
		t.Fatalf("round-trip mismatch")
	}
}

// TestNodeBlobHashMismatchRejected proves a content/hash mismatch is rejected.
func TestNodeBlobHashMismatchRejected(t *testing.T) {
	s, srv := nodeTestServer(t)
	defer srv.Close()

	data := []byte("real-content")
	wrong := hashHex([]byte("something-else"))

	resp := putNodeBlob(t, srv.URL, wrong, data)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("mismatch status = %d, want 400", resp.StatusCode)
	}
	if n := s.blobs.count(); n != 0 {
		t.Fatalf("stored %d blobs after mismatch, want 0", n)
	}
}

// TestNodeBlobOverCap proves an oversized blob is rejected.
func TestNodeBlobOverCap(t *testing.T) {
	s, _ := nodeTestServer(t)
	s.maxBlobBytes = 1024
	mux := http.NewServeMux()
	s.Register(mux)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	data := make([]byte, 4096)
	if _, err := rand.Read(data); err != nil {
		t.Fatalf("rand: %v", err)
	}
	h := hashHex(data)
	resp := putNodeBlob(t, srv.URL, h, data)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusRequestEntityTooLarge && resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("over-cap status = %d, want 413/400", resp.StatusCode)
	}
	if n := s.blobs.count(); n != 0 {
		t.Fatalf("stored %d blobs over cap, want 0", n)
	}
}

// TestNodeBlobStoresOnlyCiphertext is the CRITICAL abuse/privacy test for the
// relay: the node stores only ciphertext and never the plaintext or key.
func TestNodeBlobStoresOnlyCiphertext(t *testing.T) {
	s, srv := nodeTestServer(t)
	defer srv.Close()

	plaintext := []byte("exact home address and the words top secret")
	key := make([]byte, 32)
	nonce := make([]byte, 12)
	_, _ = rand.Read(key)
	_, _ = rand.Read(nonce)
	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatalf("cipher: %v", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		t.Fatalf("gcm: %v", err)
	}
	ciphertext := gcm.Seal(nil, nonce, plaintext, nil)

	h := hashHex(ciphertext)
	resp := putNodeBlob(t, srv.URL, h, ciphertext)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("put status = %d, want 201", resp.StatusCode)
	}

	stored, ok := s.blobs.get(h)
	if !ok {
		t.Fatalf("blob not stored")
	}
	if !bytes.Equal(stored, ciphertext) {
		t.Fatalf("stored bytes differ from uploaded ciphertext")
	}
	if bytes.Contains(stored, plaintext) || strings.Contains(string(stored), "top secret") {
		t.Fatalf("node stored readable plaintext — privacy violation")
	}
	if bytes.Contains(stored, key) {
		t.Fatalf("node stored the decryption key — privacy violation")
	}
}

// TestNodeBlobRateLimit proves a caller exceeding the write limit is throttled.
func TestNodeBlobRateLimit(t *testing.T) {
	s, _ := nodeTestServer(t)
	s.blobLimiter = newRateLimiter(2, time.Hour)
	mux := http.NewServeMux()
	s.Register(mux)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	var last int
	for i := 0; i < 4; i++ {
		data := []byte{byte(i + 1), 9, 9}
		resp := putNodeBlob(t, srv.URL, hashHex(data), data)
		last = resp.StatusCode
		resp.Body.Close()
	}
	if last != http.StatusTooManyRequests {
		t.Fatalf("expected 429, got %d", last)
	}
}
