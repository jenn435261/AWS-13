package api

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/resilience-network/aws13/cloud/internal/store"
)

// The offline app-shell service worker needs the shell to be CACHEABLE (never
// no-store), while app-config.json must stay no-store (network-first) and the
// shell entry points / the worker script must be revalidated (no-cache) so a
// new deploy is picked up.
func TestWebShellCacheHeaders(t *testing.T) {
	dir := t.TempDir()
	write := func(name, body string) {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(body), 0o644); err != nil {
			t.Fatalf("write %s: %v", name, err)
		}
	}
	write("index.html", "<!doctype html><title>shell</title>")
	write("sw.js", "// worker")
	write("main.dart.js", "// app")
	write("sqlite3.wasm", "wasm")
	write("drift_worker.js", "// drift")

	srv := httptest.NewServer(NewServer(store.NewMemStore(), WithWebDir(dir)).Handler())
	defer srv.Close()

	get := func(path string) *http.Response {
		resp, err := http.Get(srv.URL + path)
		if err != nil {
			t.Fatalf("get %s: %v", path, err)
		}
		return resp
	}

	// app-config.json: no-store (network-first; the worker falls back to cache).
	cfg := get("/app-config.json")
	defer cfg.Body.Close()
	if cc := cfg.Header.Get("Cache-Control"); cc != "no-store" {
		t.Fatalf("app-config.json Cache-Control = %q, want no-store", cc)
	}

	// index.html: no-cache (revalidate) but NOT no-store, so the shell caches.
	idx := get("/index.html")
	defer idx.Body.Close()
	if cc := idx.Header.Get("Cache-Control"); cc != "no-cache" {
		t.Fatalf("index.html Cache-Control = %q, want no-cache", cc)
	}

	// sw.js: revalidated so worker updates propagate.
	sw := get("/sw.js")
	defer sw.Body.Close()
	if cc := sw.Header.Get("Cache-Control"); cc != "no-cache" {
		t.Fatalf("sw.js Cache-Control = %q, want no-cache", cc)
	}

	// The local-DB assets must be cacheable (no no-store) for an offline boot.
	for _, name := range []string{"/sqlite3.wasm", "/drift_worker.js", "/main.dart.js"} {
		resp := get(name)
		cc := resp.Header.Get("Cache-Control")
		resp.Body.Close()
		if cc == "no-store" {
			t.Fatalf("%s Cache-Control = %q, must not be no-store (shell must cache)", name, cc)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("%s status = %d, want 200", name, resp.StatusCode)
		}
	}
}
