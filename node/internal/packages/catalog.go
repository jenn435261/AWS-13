package packages

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Item is one downloadable artifact the node holds.
type Item struct {
	Kind       string `json:"kind"` // "app" | "map" | "readiness"
	Name       string `json:"name"`
	Path       string `json:"path"` // URL path on this node, e.g. /node/v1/map/bay.pmtiles
	SizeBytes  int64  `json:"size_bytes"`
	ModifiedMs int64  `json:"modified_ms"`
}

// Catalog lists what the node actually serves, so clients never have to guess
// file names. Empty directories yield an empty list, never an error.
func (s *Server) Catalog() []Item {
	items := []Item{}
	if s.cfg.APKDir != "" {
		if f := pickAPK(s.cfg.APKDir); f != "" {
			items = append(items, itemFor("app", filepath.Base(f), "/node/v1/apk", f))
		}
	}
	items = append(items, listDir("map", s.cfg.MapDir, "/node/v1/map/", ".pmtiles")...)
	items = append(items, listDir("readiness", s.cfg.ReadinessDir, "/node/v1/readiness/", "")...)
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Kind != items[j].Kind {
			return items[i].Kind < items[j].Kind
		}
		return items[i].Name < items[j].Name
	})
	return items
}

func listDir(kind, dir, prefix, suffix string) []Item {
	if dir == "" {
		return nil
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var out []Item
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !safeName(name) || (suffix != "" && !strings.HasSuffix(name, suffix)) {
			continue
		}
		out = append(out, itemFor(kind, name, prefix+name, filepath.Join(dir, name)))
	}
	return out
}

func itemFor(kind, name, urlPath, file string) Item {
	it := Item{Kind: kind, Name: name, Path: urlPath}
	if fi, err := os.Stat(file); err == nil {
		it.SizeBytes = fi.Size()
		it.ModifiedMs = fi.ModTime().UnixMilli()
	}
	return it
}

func (s *Server) handleCatalog(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"items": s.Catalog()})
}
