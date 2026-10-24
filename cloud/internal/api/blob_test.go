package api

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

	"github.com/resilience-network/aws13/cloud/internal/store"
)

// putBlob is a test helper that PUTs data at /v1/blobs/{hash} with the given
// client key and returns the response.
func putBlob(t *testing.T, base, hash string, data []byte, apiKey string) *http.Response {
	t.Helper()
	req, err := http.NewRequest(http.MethodPut, base+"/v1/blobs/"+hash, bytes.NewReader(data))
	if err != nil {
		t.Fatalf("new put: %v", err)
	}
	if apiKey != "" {
		req.Header.Set("X-Api-Key", apiKey)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do put: %v", err)
	}
	return resp
}

func getBlob(t *testing.T, base, hash, apiKey string) *http.Response {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, base+"/v1/blobs/"+hash, nil)
	if err != nil {
		t.Fatalf("new get: %v", err)
	}
	if apiKey != "" {
		req.Header.Set("X-Api-Key", apiKey)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do get: %v", err)
	}
	return resp
}

func hashHex(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

// TestBlobRoundTrip proves a PUT then GET by hash returns the same bytes.
func TestBlobRoundTrip(t *testing.T) {
	srv := httptest.NewServer(NewServer(store.NewMemStore(), WithClientTokens([]string{"devkey"})).Handler())
	defer srv.Close()

	data := []byte("opaque-ciphertext-bytes-abc123")
	h := hashHex(data)

	resp := putBlob(t, srv.URL, h, data, "devkey")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("put status = %d, want 201", resp.StatusCode)
	}

	resp2 := getBlob(t, srv.URL, h, "devkey")
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusOK {
		t.Fatalf("get status = %d, want 200", resp2.StatusCode)
	}
	got, _ := io.ReadAll(resp2.Body)
	if !bytes.Equal(got, data) {
		t.Fatalf("round-trip mismatch: got %q want %q", got, data)
	}
}

// TestBlobHashMismatchRejected proves a PUT whose path hash does not match the
// body is rejected with 400 and nothing is stored.
func TestBlobHashMismatchRejected(t *testing.T) {
	s := NewServer(store.NewMemStore(), WithClientTokens([]string{"devkey"}))
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	data := []byte("real-content")
	wrong := hashHex([]byte("different-content"))

	resp := putBlob(t, srv.URL, wrong, data, "devkey")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("mismatch put status = %d, want 400", resp.StatusCode)
	}
	if n := s.blobs.count(); n != 0 {
		t.Fatalf("stored %d blobs after mismatch, want 0", n)
	}
}

// TestBlobOverCap proves a blob larger than the cap is rejected.
func TestBlobOverCap(t *testing.T) {
	s := NewServer(store.NewMemStore(), WithClientTokens([]string{"devkey"}))
	s.maxBlobBytes = 1024 // shrink cap for the test
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	data := make([]byte, 2048)
	if _, err := rand.Read(data); err != nil {
		t.Fatalf("rand: %v", err)
	}
	h := hashHex(data)
	resp := putBlob(t, srv.URL, h, data, "devkey")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusRequestEntityTooLarge && resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("over-cap put status = %d, want 413/400", resp.StatusCode)
	}
	if n := s.blobs.count(); n != 0 {
		t.Fatalf("stored %d blobs over cap, want 0", n)
	}
}

// TestBlobRequiresClientKey proves the cloud blob endpoint is gated: no key
// means 401, and the wrong key means 401.
func TestBlobRequiresClientKey(t *testing.T) {
	srv := httptest.NewServer(NewServer(store.NewMemStore(), WithClientTokens([]string{"devkey"})).Handler())
	defer srv.Close()

	data := []byte("ciphertext")
	h := hashHex(data)

	// No key.
	resp := putBlob(t, srv.URL, h, data, "")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("no-key put status = %d, want 401", resp.StatusCode)
	}
	// Wrong key.
	resp2 := putBlob(t, srv.URL, h, data, "wrongkey")
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusUnauthorized {
		t.Fatalf("wrong-key put status = %d, want 401", resp2.StatusCode)
	}
}

// TestBlobStoresOnlyCiphertext is the CRITICAL abuse/privacy test. A client
// AES-GCM-encrypts a sensitive plaintext with a random key, uploads ONLY the
// ciphertext (never the key), and we assert that:
//   - the bytes the server holds are exactly the ciphertext, and
//   - the plaintext and the key never appear anywhere in the server's storage.
//
// The server cannot decrypt without the key, which never left the client, so a
// stored blob is useless to anyone but the recipient.
func TestBlobStoresOnlyCiphertext(t *testing.T) {
	s := NewServer(store.NewMemStore(), WithClientTokens([]string{"devkey"}))
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	plaintext := []byte("GPS: 37.7749,-122.4194 secret meeting point and victim name")
	key := make([]byte, 32)
	nonce := make([]byte, 12)
	if _, err := rand.Read(key); err != nil {
		t.Fatalf("rand key: %v", err)
	}
	if _, err := rand.Read(nonce); err != nil {
		t.Fatalf("rand nonce: %v", err)
	}
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
	resp := putBlob(t, srv.URL, h, ciphertext, "devkey")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("put ciphertext status = %d, want 201", resp.StatusCode)
	}

	// The stored bytes must be EXACTLY the ciphertext.
	stored, ok := s.blobs.get(h)
	if !ok {
		t.Fatalf("blob not stored")
	}
	if !bytes.Equal(stored, ciphertext) {
		t.Fatalf("stored bytes differ from uploaded ciphertext")
	}
	// The plaintext must never appear in what the server holds.
	if bytes.Contains(stored, plaintext) {
		t.Fatalf("server stored the plaintext — privacy violation")
	}
	if bytes.Contains(stored, []byte("37.7749")) || strings.Contains(string(stored), "victim") {
		t.Fatalf("server stored readable coordinates/content — privacy violation")
	}
	// The decryption key must never appear in storage (it never left the client).
	if bytes.Contains(stored, key) {
		t.Fatalf("server stored the decryption key — privacy violation")
	}
}

// TestBlobRateLimit proves a caller exceeding the write limit is throttled.
func TestBlobRateLimit(t *testing.T) {
	s := NewServer(store.NewMemStore(), WithClientTokens([]string{"devkey"}))
	s.blobLimiter = newRateLimiter(2, time.Hour)
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	var lastStatus int
	for i := 0; i < 4; i++ {
		data := []byte{byte(i), byte(i), byte(i)}
		h := hashHex(data)
		resp := putBlob(t, srv.URL, h, data, "devkey")
		lastStatus = resp.StatusCode
		resp.Body.Close()
	}
	if lastStatus != http.StatusTooManyRequests {
		t.Fatalf("expected 429 after exceeding rate limit, got %d", lastStatus)
	}
}
