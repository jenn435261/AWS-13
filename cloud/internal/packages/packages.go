// Package packages serves large static artifacts (region map packs as PMTiles,
// plus readiness/guidance bundles) from the cloud with HTTP Range support and a
// cloud-signed manifest. It mirrors node/internal/packages so the APP uses the
// SAME signed-manifest + SHA-256 verification flow for a cloud pack as for a
// node pack: the only difference is the cloud signs with its OWN packages
// signing key (a distinct trusted root).
//
// Endpoints (mounted by the api Server):
//
//	GET /v1/packages          — the catalog (JSON {items:[...]}) of what we serve
//	GET /v1/packages/manifest — the cloud-signed manifest (503 if no signing key)
//	GET /v1/packages/{id}     — one artifact, with Range via http.ServeContent
//
// Missing files => 404. Path traversal is rejected. The {id} is the artifact's
// safe single-segment file name.
package packages

import (
	"crypto/ed25519"
	"encoding/json"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Config names the directory the cloud package server reads map/readiness packs
// from. An empty dir disables serving (routes still exist but 404/empty).
type Config struct {
	// PackDir holds the servable artifacts (e.g. <region>.pmtiles, guidance
	// bundles). Each top-level file is one downloadable item.
	PackDir string
}

// Server serves cloud packages.
type Server struct {
	cfg        Config
	signingKey ed25519.PrivateKey
}

// New returns a cloud package Server for the given config.
func New(cfg Config) *Server { return &Server{cfg: cfg} }

// WithSigningKey installs the private key used to sign the served manifest.
// When nil, /v1/packages/manifest returns 503 (the cloud refuses to serve an
// unsigned manifest so a client is never tricked into trusting one).
func (s *Server) WithSigningKey(priv ed25519.PrivateKey) { s.signingKey = priv }

// Enabled reports whether a pack directory is configured.
func (s *Server) Enabled() bool { return s.cfg.PackDir != "" }

// Register mounts the cloud package endpoints on mux. The caller wraps them in
// its own client gate / CORS as needed.
func (s *Server) Register(mux *http.ServeMux, gate func(http.HandlerFunc) http.HandlerFunc) {
	wrap := func(h http.HandlerFunc) http.HandlerFunc {
		if gate == nil {
			return h
		}
		return gate(h)
	}
	mux.HandleFunc("/v1/packages", wrap(s.handleCatalogOrItem))
	mux.HandleFunc("/v1/packages/", wrap(s.handleCatalogOrItem))
}

// handleCatalogOrItem dispatches:
//
//	/v1/packages            -> catalog
//	/v1/packages/manifest   -> signed manifest
//	/v1/packages/{id}       -> one artifact (Range)
func (s *Server) handleCatalogOrItem(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	rest := strings.TrimPrefix(r.URL.Path, "/v1/packages")
	rest = strings.TrimPrefix(rest, "/")
	switch {
	case rest == "":
		s.handleCatalog(w, r)
	case rest == "manifest":
		s.handleManifest(w, r)
	default:
		s.handleItem(w, r, rest)
	}
}

func (s *Server) handleCatalog(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"items": s.Catalog()})
}

func (s *Server) handleItem(w http.ResponseWriter, r *http.Request, id string) {
	if s.cfg.PackDir == "" {
		http.NotFound(w, r)
		return
	}
	if id == "" || !safeName(id) {
		http.NotFound(w, r)
		return
	}
	full := joinSafe(s.cfg.PackDir, id)
	if full == "" {
		http.NotFound(w, r)
		return
	}
	if strings.HasSuffix(id, ".pmtiles") {
		w.Header().Set("Content-Type", "application/vnd.pmtiles")
	}
	serveFile(w, r, full)
}

// Item is one downloadable artifact the cloud holds.
type Item struct {
	Kind       string `json:"kind"` // "map" | "guidance"
	Name       string `json:"name"`
	Path       string `json:"path"` // URL path, e.g. /v1/packages/bay.pmtiles
	SizeBytes  int64  `json:"size_bytes"`
	ModifiedMs int64  `json:"modified_ms"`
}

// Catalog lists what the cloud actually serves. Empty dir => empty list.
func (s *Server) Catalog() []Item {
	items := []Item{}
	if s.cfg.PackDir == "" {
		return items
	}
	entries, err := os.ReadDir(s.cfg.PackDir)
	if err != nil {
		return items
	}
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !safeName(name) {
			continue
		}
		it := Item{Kind: kindFor(name), Name: name, Path: "/v1/packages/" + name}
		if fi, serr := os.Stat(filepath.Join(s.cfg.PackDir, name)); serr == nil {
			it.SizeBytes = fi.Size()
			it.ModifiedMs = fi.ModTime().UnixMilli()
		}
		items = append(items, it)
	}
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Kind != items[j].Kind {
			return items[i].Kind < items[j].Kind
		}
		return items[i].Name < items[j].Name
	})
	return items
}

func kindFor(name string) string {
	if strings.HasSuffix(name, ".pmtiles") {
		return "map"
	}
	return "guidance"
}

// serveFile streams file via http.ServeContent (Range, If-Modified-Since, HEAD).
func serveFile(w http.ResponseWriter, r *http.Request, file string) {
	f, err := os.Open(file)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil || fi.IsDir() {
		http.NotFound(w, r)
		return
	}
	modtime := fi.ModTime()
	if modtime.IsZero() {
		modtime = time.Now()
	}
	http.ServeContent(w, r, filepath.Base(file), modtime, f)
}

// safeName rejects empty names, traversal, and multi-segment names.
func safeName(name string) bool {
	if name == "" || strings.Contains(name, "..") {
		return false
	}
	if strings.ContainsAny(name, "/\\") {
		return false
	}
	return path.Clean(name) == name
}

// joinSafe joins a single safe name onto dir and returns the path only if it
// stays within dir; otherwise "".
func joinSafe(dir, name string) string {
	full := filepath.Join(dir, filepath.Clean("/"+name))
	rel, err := filepath.Rel(dir, full)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) || filepath.IsAbs(rel) {
		return ""
	}
	return full
}

func nowMs() int64 { return time.Now().UnixMilli() }
