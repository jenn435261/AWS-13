// Package packages serves large static artifacts to phones over local Wi-Fi:
// the Android APK, offline map tiles (PMTiles), and readiness/first-aid
// bundles. It uses http.ServeContent so conditional requests and HTTP Range
// requests (essential for large PMTiles maps that clients stream in pieces)
// are handled correctly, including 206 Partial Content and 416 responses.
//
// Endpoints:
//
//	GET /node/v1/apk                       — the Android APK
//	GET /node/v1/map/{region}.pmtiles       — an offline map for a region
//	GET /node/v1/readiness/{id}             — a readiness/first-aid bundle
//
// Missing files return 404. Path traversal (".." / absolute segments) is
// rejected. Content types are set appropriately.
package packages

import (
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"
)

// Config names the directories the package server reads from. Any empty dir
// disables its endpoint (the route still exists but always 404s).
type Config struct {
	// APKDir holds the Android APK. The server serves the first *.apk found,
	// or a file named exactly "app-release.apk" / "resilience.apk" if present.
	APKDir string
	// MapDir holds <region>.pmtiles files.
	MapDir string
	// ReadinessDir holds readiness bundles addressed by id.
	ReadinessDir string
}

// Server serves packages from configured directories.
type Server struct {
	cfg Config
}

// New returns a package Server for the given config.
func New(cfg Config) *Server { return &Server{cfg: cfg} }

// Register mounts the package endpoints on mux.
func (s *Server) Register(mux *http.ServeMux) {
	mux.HandleFunc("/node/v1/apk", s.handleAPK)
	mux.HandleFunc("/node/v1/map/", s.handleMap)
	mux.HandleFunc("/node/v1/readiness/", s.handleReadiness)
}

func (s *Server) handleAPK(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if s.cfg.APKDir == "" {
		http.NotFound(w, r)
		return
	}
	file := pickAPK(s.cfg.APKDir)
	if file == "" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/vnd.android.package-archive")
	w.Header().Set("Content-Disposition", `attachment; filename="resilience.apk"`)
	serveFile(w, r, file)
}

func (s *Server) handleMap(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if s.cfg.MapDir == "" {
		http.NotFound(w, r)
		return
	}
	name := strings.TrimPrefix(r.URL.Path, "/node/v1/map/")
	// Only allow "<region>.pmtiles" with a safe single-segment name.
	if name == "" || !strings.HasSuffix(name, ".pmtiles") || !safeName(name) {
		http.NotFound(w, r)
		return
	}
	full := filepath.Join(s.cfg.MapDir, filepath.Clean("/"+name))
	if !withinDir(s.cfg.MapDir, full) {
		http.NotFound(w, r)
		return
	}
	// PMTiles is a single-file archive; this content type + range support lets
	// clients fetch just the header and the tiles they need.
	w.Header().Set("Content-Type", "application/vnd.pmtiles")
	serveFile(w, r, full)
}

func (s *Server) handleReadiness(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if s.cfg.ReadinessDir == "" {
		http.NotFound(w, r)
		return
	}
	id := strings.TrimPrefix(r.URL.Path, "/node/v1/readiness/")
	if id == "" || !safeName(id) {
		http.NotFound(w, r)
		return
	}
	full := filepath.Join(s.cfg.ReadinessDir, filepath.Clean("/"+id))
	if !withinDir(s.cfg.ReadinessDir, full) {
		http.NotFound(w, r)
		return
	}
	// Content type is inferred from extension by ServeContent; default to
	// octet-stream for extensionless ids.
	if filepath.Ext(id) == "" {
		w.Header().Set("Content-Type", "application/octet-stream")
	}
	serveFile(w, r, full)
}

// serveFile opens file and streams it via http.ServeContent, which implements
// Range, If-Modified-Since, and HEAD handling. Missing files => 404.
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

// pickAPK returns a path to an APK in dir, preferring well-known names.
func pickAPK(dir string) string {
	for _, name := range []string{"resilience.apk", "app-release.apk"} {
		p := filepath.Join(dir, name)
		if fi, err := os.Stat(p); err == nil && !fi.IsDir() {
			return p
		}
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	for _, e := range entries {
		if !e.IsDir() && strings.EqualFold(filepath.Ext(e.Name()), ".apk") {
			return filepath.Join(dir, e.Name())
		}
	}
	return ""
}

// safeName rejects empty names, traversal, and multi-segment names: a safe
// name is a single path segment with no slashes and no "..".
func safeName(name string) bool {
	if name == "" || strings.Contains(name, "..") {
		return false
	}
	if strings.ContainsAny(name, "/\\") {
		return false
	}
	return path.Clean(name) == name
}

// withinDir reports whether full resolves to a path inside dir.
func withinDir(dir, full string) bool {
	rel, err := filepath.Rel(dir, full)
	if err != nil {
		return false
	}
	return rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator)) && !filepath.IsAbs(rel)
}
