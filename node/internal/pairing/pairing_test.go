package pairing

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPairJSONUsesRequestHost(t *testing.T) {
	mux := http.NewServeMux()
	New(Config{Name: "Shelter 18"}).Register(mux)
	req := httptest.NewRequest("GET", "http://192.168.1.20:8090/node/v1/pair", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	var p Payload
	if err := json.Unmarshal(rec.Body.Bytes(), &p); err != nil {
		t.Fatal(err)
	}
	if p.URL != "http://192.168.1.20:8090" || p.Name != "Shelter 18" || p.V != 1 {
		t.Fatalf("unexpected payload %+v", p)
	}
}

func TestPublicURLOverridesHost(t *testing.T) {
	mux := http.NewServeMux()
	New(Config{PublicURL: "https://node.example.org/"}).Register(mux)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "http://x/node/v1/pair", nil))
	var p Payload
	_ = json.Unmarshal(rec.Body.Bytes(), &p)
	if p.URL != "https://node.example.org" {
		t.Fatalf("got %q", p.URL)
	}
}

func TestPairPNG(t *testing.T) {
	mux := http.NewServeMux()
	New(Config{}).Register(mux)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "http://h:1/node/v1/pair.png", nil))
	if rec.Code != 200 || rec.Header().Get("Content-Type") != "image/png" {
		t.Fatalf("code %d type %s", rec.Code, rec.Header().Get("Content-Type"))
	}
	if b := rec.Body.Bytes(); len(b) < 8 || string(b[1:4]) != "PNG" {
		t.Fatal("not a PNG")
	}
}
