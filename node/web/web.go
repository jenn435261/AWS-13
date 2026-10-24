// Package web embeds the static assets for the offline Resilience web app.
// Keeping the embed here lets the canonical source live at node/web/index.html
// (as named in the spec) while still shipping inside the single daemon binary.
package web

import _ "embed"

// IndexHTML is the dependency-free offline web app page (vanilla HTML/JS, no
// CDN, no external fonts). Served at GET / by the webapp handler.
//
//go:embed index.html
var IndexHTML []byte
