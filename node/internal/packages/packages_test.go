package packages

import (
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func writeFile(t *testing.T, dir, name string, data []byte) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, name), data, 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
}

func newServer(t *testing.T, cfg Config) *httptest.Server {
	t.Helper()
	mux := http.NewServeMux()
	New(cfg).Register(mux)
	ts := httptest.NewServer(mux)
	t.Cleanup(ts.Close)
	return ts
}

func TestServesAPK(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "resilience.apk", []byte("APKDATA"))
	ts := newServer(t, Config{APKDir: dir})

	resp, err := http.Get(ts.URL + "/node/v1/apk")
	if err != nil {
		t.Fatalf("get apk: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("apk status = %d", resp.StatusCode)
	}
	if ct := resp.Header.Get("Content-Type"); ct != "application/vnd.android.package-archive" {
		t.Fatalf("apk content-type = %q", ct)
	}
	body, _ := io.ReadAll(resp.Body)
	if string(body) != "APKDATA" {
		t.Fatalf("apk body = %q", string(body))
	}
}

func TestAPK404WhenAbsent(t *testing.T) {
	ts := newServer(t, Config{APKDir: t.TempDir()})
	resp, err := http.Get(ts.URL + "/node/v1/apk")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestServesMapWithRange(t *testing.T) {
	dir := t.TempDir()
	// 256 bytes of predictable content.
	data := make([]byte, 256)
	for i := range data {
		data[i] = byte(i)
	}
	writeFile(t, dir, "bayarea.pmtiles", data)
	ts := newServer(t, Config{MapDir: dir})

	// Full request.
	full, err := http.Get(ts.URL + "/node/v1/map/bayarea.pmtiles")
	if err != nil {
		t.Fatalf("get map: %v", err)
	}
	defer full.Body.Close()
	if full.StatusCode != http.StatusOK {
		t.Fatalf("map status = %d", full.StatusCode)
	}
	if ar := full.Header.Get("Accept-Ranges"); ar != "bytes" {
		t.Fatalf("expected Accept-Ranges: bytes, got %q", ar)
	}

	// Range request: bytes 10-19 (10 bytes).
	req, _ := http.NewRequest(http.MethodGet, ts.URL+"/node/v1/map/bayarea.pmtiles", nil)
	req.Header.Set("Range", "bytes=10-19")
	part, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("range get: %v", err)
	}
	defer part.Body.Close()
	if part.StatusCode != http.StatusPartialContent {
		t.Fatalf("expected 206, got %d", part.StatusCode)
	}
	got, _ := io.ReadAll(part.Body)
	if len(got) != 10 {
		t.Fatalf("range body len = %d, want 10", len(got))
	}
	for i := 0; i < 10; i++ {
		if got[i] != byte(10+i) {
			t.Fatalf("range byte %d = %d, want %d", i, got[i], 10+i)
		}
	}
}

func TestMapRejectsTraversal(t *testing.T) {
	dir := t.TempDir()
	ts := newServer(t, Config{MapDir: dir})
	resp, err := http.Get(ts.URL + "/node/v1/map/..%2f..%2fetc%2fpasswd.pmtiles")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404 for traversal, got %d", resp.StatusCode)
	}
}

func TestServesReadiness(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "first-aid.json", []byte(`{"ok":true}`))
	ts := newServer(t, Config{ReadinessDir: dir})

	resp, err := http.Get(ts.URL + "/node/v1/readiness/first-aid.json")
	if err != nil {
		t.Fatalf("get readiness: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("readiness status = %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)
	if string(body) != `{"ok":true}` {
		t.Fatalf("readiness body = %q", string(body))
	}
}

func TestReadiness404WhenAbsent(t *testing.T) {
	ts := newServer(t, Config{ReadinessDir: t.TempDir()})
	resp, err := http.Get(ts.URL + "/node/v1/readiness/missing.json")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestCatalogListsRealFiles(t *testing.T) {
	maps := t.TempDir()
	_ = os.WriteFile(filepath.Join(maps, "bay.pmtiles"), []byte("12345"), 0o644)
	_ = os.WriteFile(filepath.Join(maps, "notes.txt"), []byte("x"), 0o644)
	items := New(Config{MapDir: maps}).Catalog()
	if len(items) != 1 || items[0].Name != "bay.pmtiles" || items[0].SizeBytes != 5 || items[0].Kind != "map" {
		t.Fatalf("unexpected catalog %+v", items)
	}
	if got := New(Config{}).Catalog(); got == nil || len(got) != 0 {
		t.Fatalf("empty config must give an empty non-nil list, got %v", got)
	}
}
