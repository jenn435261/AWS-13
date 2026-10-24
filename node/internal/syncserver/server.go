// Package syncserver exposes the HTTP endpoints a phone uses to reconcile with
// the node over local Wi-Fi. It talks protobuf or JSON (content-negotiated),
// verifies every pushed event before storing it (the cache enforces this), and
// serves a folded JSON state view for the offline web app.
//
// Endpoints:
//
//	POST /node/v1/push   — accept a batch of events, verify+store, return ack
//	POST /node/v1/pull   — given per-author watermarks, return missing events
//	GET  /node/v1/have    — per-author high-water digest (JSON)
//	GET  /node/v1/state   — current resources/alerts folded from events (JSON)
//	GET  /healthz         — liveness
package syncserver

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/cache"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

const (
	contentTypeProto = "application/x-protobuf"
	contentTypeJSON  = "application/json"

	defaultMaxBodyBytes = 16 << 20 // 16 MiB
)

// Server wires the sync endpoints over a Cache.
type Server struct {
	cache        *cache.Cache
	maxBodyBytes int64
}

// New returns a sync Server backed by the given cache.
func New(c *cache.Cache) *Server {
	return &Server{cache: c, maxBodyBytes: defaultMaxBodyBytes}
}

// Register mounts the sync endpoints on mux. The web app ("/") and the package
// server are mounted separately by the daemon.
func (s *Server) Register(mux *http.ServeMux) {
	mux.HandleFunc("/node/v1/push", s.handlePush)
	mux.HandleFunc("/node/v1/pull", s.handlePull)
	mux.HandleFunc("/node/v1/have", s.handleHave)
	mux.HandleFunc("/node/v1/state", s.handleState)
	mux.HandleFunc("/healthz", s.handleHealthz)
}

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", contentTypeJSON)
	w.WriteHeader(http.StatusOK)
	_, _ = io.WriteString(w, `{"status":"ok"}`)
}

// handlePush implements POST /node/v1/push: decode a PushEventsRequest (proto
// or JSON), verify+store via the cache, and return a PushEventsResponse Ack
// listing applied and rejected event ids.
func (s *Server) handlePush(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	req := &resiliencev1.PushEventsRequest{}
	useJSON, err := s.decode(r, req)
	if err != nil {
		s.writeError(w, http.StatusBadRequest, "decode request: "+err.Error())
		return
	}

	applied, rejected, err := s.cache.Push(r.Context(), req.GetEvents())
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "store push: "+err.Error())
		return
	}

	resp := &resiliencev1.PushEventsResponse{
		Ack: &resiliencev1.Ack{Applied: applied, Rejected: rejected},
	}
	s.writeMessage(w, r, resp, useJSON, http.StatusOK)
}

// handlePull implements POST/GET /node/v1/pull: given per-author watermarks,
// return events strictly above each watermark (the events the caller is
// missing).
func (s *Server) handlePull(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost && r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	req := &resiliencev1.PullEventsRequest{}
	useJSON, err := s.decode(r, req)
	if err != nil {
		s.writeError(w, http.StatusBadRequest, "decode request: "+err.Error())
		return
	}

	from := make(map[string]uint64, len(req.GetFrom()))
	for _, af := range req.GetFrom() {
		from[cache.AuthorKey(af.GetAuthorPubkey())] = af.GetFromLamport()
	}

	evs, err := s.cache.PullAbove(r.Context(), from, int(req.GetLimit()))
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "store pull: "+err.Error())
		return
	}

	// Optional coarse geo filter on h3_cell (header bucket).
	if req.GetH3Cell() != 0 {
		filtered := evs[:0:0]
		for _, ev := range evs {
			if ev.GetHeader().GetH3Cell() == req.GetH3Cell() {
				filtered = append(filtered, ev)
			}
		}
		evs = filtered
	}

	resp := &resiliencev1.PullEventsResponse{
		Batch: &resiliencev1.EventBatch{Events: evs, More: false},
	}
	s.writeMessage(w, r, resp, useJSON, http.StatusOK)
}

// haveResponse is the JSON shape of GET /node/v1/have.
type haveResponse struct {
	Authors []cache.Head `json:"authors"`
}

func (s *Server) handleHave(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	heads, err := s.cache.Heads(r.Context())
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "have: "+err.Error())
		return
	}
	s.writeJSON(w, haveResponse{Authors: heads})
}

func (s *Server) handleState(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	evs, err := s.cache.All(r.Context())
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "state: "+err.Error())
		return
	}
	s.writeJSON(w, FoldState(evs))
}

// --- content negotiation helpers (proto/JSON), mirroring the cloud API ---

func (s *Server) decode(r *http.Request, msg proto.Message) (useJSON bool, err error) {
	useJSON = isJSON(r.Header.Get("Content-Type"))
	body, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, s.maxBodyBytes))
	if err != nil {
		return useJSON, fmt.Errorf("read body: %w", err)
	}
	if len(body) == 0 {
		return useJSON, nil
	}
	if useJSON {
		if err := protojson.Unmarshal(body, msg); err != nil {
			return useJSON, err
		}
		return useJSON, nil
	}
	if err := proto.Unmarshal(body, msg); err != nil {
		return useJSON, err
	}
	return useJSON, nil
}

func (s *Server) writeMessage(rw http.ResponseWriter, r *http.Request, msg proto.Message, reqWasJSON bool, status int) {
	useJSON := reqWasJSON || isJSON(r.Header.Get("Accept"))
	var (
		out []byte
		err error
		ct  string
	)
	if useJSON {
		out, err = protojson.Marshal(msg)
		ct = contentTypeJSON
	} else {
		out, err = proto.Marshal(msg)
		ct = contentTypeProto
	}
	if err != nil {
		s.writeError(rw, http.StatusInternalServerError, "encode response: "+err.Error())
		return
	}
	rw.Header().Set("Content-Type", ct)
	rw.WriteHeader(status)
	_, _ = rw.Write(out)
}

func (s *Server) writeJSON(rw http.ResponseWriter, v any) {
	out, err := json.Marshal(v)
	if err != nil {
		s.writeError(rw, http.StatusInternalServerError, "encode response: "+err.Error())
		return
	}
	rw.Header().Set("Content-Type", contentTypeJSON)
	rw.WriteHeader(http.StatusOK)
	_, _ = rw.Write(out)
}

func (s *Server) writeError(rw http.ResponseWriter, status int, msg string) {
	rw.Header().Set("Content-Type", contentTypeJSON)
	rw.WriteHeader(status)
	_, _ = io.WriteString(rw, fmt.Sprintf(`{"error":%q}`, msg))
}

func isJSON(contentType string) bool {
	for i := 0; i < len(contentType); i++ {
		if contentType[i] == ';' {
			contentType = contentType[:i]
			break
		}
	}
	return trimSpace(contentType) == contentTypeJSON
}

func trimSpace(s string) string {
	start := 0
	for start < len(s) && (s[start] == ' ' || s[start] == '\t') {
		start++
	}
	end := len(s)
	for end > start && (s[end-1] == ' ' || s[end-1] == '\t') {
		end--
	}
	return s[start:end]
}

// hexID renders an event id for JSON views.
func hexID(b []byte) string { return hex.EncodeToString(b) }
