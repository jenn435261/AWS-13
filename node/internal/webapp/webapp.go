// Package webapp serves the dependency-free, offline Resilience web app: a
// single vanilla HTML/JS page with no CDN, no external fonts, and no build
// step. It is the iOS / no-native-app fallback (spec §52): a phone that cannot
// install the native app can still join the node over local Wi-Fi, open the
// node's address in a browser, and see current resources and alerts fetched
// from /node/v1/state.
package webapp

import (
	"net/http"

	"github.com/resilience-network/aws13/node/web"
)

// Handler returns an http.Handler that serves the offline web app at its mount
// path. It only answers GET/HEAD for the root path; everything else 404s so it
// can be composed under a shared mux without shadowing the API routes.
func Handler() http.Handler {
	index := web.IndexHTML
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-cache")
		w.WriteHeader(http.StatusOK)
		if r.Method == http.MethodHead {
			return
		}
		_, _ = w.Write(index)
	})
}
