// Package pairing lets a phone learn a node's address by scanning a QR code.
//
//	GET /node/v1/pair      — JSON {v,name,url} describing this node
//	GET /node/v1/pair.png  — QR code encoding that same JSON
//
// The URL is built from the request's own Host header, so whichever address
// the phone used to reach the node is the one it saves. An operator can pin
// the advertised address with PUBLIC_URL when the node sits behind a proxy.
package pairing

import (
	"encoding/json"
	"net/http"
	"strings"

	qrcode "github.com/skip2/go-qrcode"
)

// Config names the node for display and optionally pins its public URL.
type Config struct {
	Name      string
	PublicURL string
}

// Payload is what the QR code carries and /node/v1/pair returns.
type Payload struct {
	V    int    `json:"v"`
	Name string `json:"name"`
	URL  string `json:"url"`
}

type Server struct{ cfg Config }

func New(cfg Config) *Server {
	if strings.TrimSpace(cfg.Name) == "" {
		cfg.Name = "Resilience Node"
	}
	return &Server{cfg: cfg}
}

func (s *Server) Register(mux *http.ServeMux) {
	mux.HandleFunc("/node/v1/pair", s.handleJSON)
	mux.HandleFunc("/node/v1/pair.png", s.handlePNG)
}

func (s *Server) payload(r *http.Request) Payload {
	url := strings.TrimRight(s.cfg.PublicURL, "/")
	if url == "" {
		scheme := "http"
		if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
			scheme = "https"
		}
		url = scheme + "://" + r.Host
	}
	return Payload{V: 1, Name: s.cfg.Name, URL: url}
}

func (s *Server) handleJSON(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(s.payload(r))
}

func (s *Server) handlePNG(w http.ResponseWriter, r *http.Request) {
	b, _ := json.Marshal(s.payload(r))
	png, err := qrcode.Encode(string(b), qrcode.Medium, 320)
	if err != nil {
		http.Error(w, "qr encode failed", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "image/png")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(png)
}
