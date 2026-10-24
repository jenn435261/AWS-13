package api

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// WithWebDir serves a prebuilt Flutter web bundle from dir at "/" (single-page
// fallback to index.html) and exposes /app-config.json for the bundle to read
// its runtime config. Empty dir disables it.
//
// The config includes the first CLIENT_API_KEYS token, so the key is public to
// anyone who can load the web app. That is deliberate: the gate is an abuse
// guard for non-browser callers, not user authentication.
func WithWebDir(dir string) Option {
	return func(s *Server) { s.webDir = dir }
}

func (s *Server) mountWeb(mux *http.ServeMux) {
	if s.webDir == "" {
		return
	}
	mux.HandleFunc("/app-config.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-store")
		_ = json.NewEncoder(w).Encode(map[string]string{
			// Empty baseUrl => the app uses its own origin.
			"baseUrl": "",
			"apiKey":  s.webKey,
		})
	})
	files := http.FileServer(http.Dir(s.webDir))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/v1/") {
			http.NotFound(w, r)
			return
		}
		p := filepath.Join(s.webDir, filepath.FromSlash(filepath.Clean("/"+r.URL.Path)))
		if st, err := os.Stat(p); err != nil || st.IsDir() {
			if r.URL.Path != "/" {
				// SPA fallback for client-side routes.
				r.URL.Path = "/"
			}
		}
		// The shell entry points must always be revalidated so a new deploy is
		// picked up (no-cache = cacheable but revalidate), while the hashed
		// asset files stay cacheable with their defaults. We deliberately do
		// NOT send no-store on the shell: the offline service worker (sw.js)
		// needs to cache it for a cold offline start. sw.js itself is
		// revalidated so worker updates propagate.
		if r.URL.Path == "/" || strings.HasSuffix(r.URL.Path, ".html") ||
			strings.HasSuffix(r.URL.Path, "flutter_service_worker.js") ||
			strings.HasSuffix(r.URL.Path, "/sw.js") {
			w.Header().Set("Cache-Control", "no-cache")
		}
		files.ServeHTTP(w, r)
	})
}
