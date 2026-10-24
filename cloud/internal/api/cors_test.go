package api

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/resilience-network/aws13/cloud/internal/store"
)

// TestCORSPreflight asserts the cloud API answers an OPTIONS preflight with 204
// and the headers a browser needs before it will make a cross-origin call that
// carries X-Api-Key.
func TestCORSPreflight(t *testing.T) {
	srv := httptest.NewServer(NewServer(store.NewMemStore()).Handler())
	defer srv.Close()

	req, _ := http.NewRequest(http.MethodOptions, srv.URL+"/v1/events", nil)
	req.Header.Set("Origin", "https://example.test")
	req.Header.Set("Access-Control-Request-Method", "POST")
	req.Header.Set("Access-Control-Request-Headers", "X-Api-Key, Content-Type")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("preflight: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("preflight status = %d, want 204", resp.StatusCode)
	}
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got != "*" {
		t.Fatalf("Allow-Origin = %q, want *", got)
	}
	methods := resp.Header.Get("Access-Control-Allow-Methods")
	for _, m := range []string{"GET", "POST", "OPTIONS"} {
		if !strings.Contains(methods, m) {
			t.Fatalf("Allow-Methods = %q, missing %s", methods, m)
		}
	}
	hdrs := resp.Header.Get("Access-Control-Allow-Headers")
	for _, h := range []string{"X-Api-Key", "Content-Type"} {
		if !strings.Contains(hdrs, h) {
			t.Fatalf("Allow-Headers = %q, missing %s", hdrs, h)
		}
	}
}

// TestCORSHeadersOnActualRequest asserts the CORS origin header is present on a
// normal (non-preflight) response too, so the browser accepts the result of
// the cross-origin call.
func TestCORSHeadersOnActualRequest(t *testing.T) {
	srv := httptest.NewServer(NewServer(store.NewMemStore()).Handler())
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/healthz")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if got := resp.Header.Get("Access-Control-Allow-Origin"); got != "*" {
		t.Fatalf("Allow-Origin = %q, want *", got)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("healthz status = %d, want 200", resp.StatusCode)
	}
}
