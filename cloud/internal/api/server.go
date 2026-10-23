// Package api implements the slim HTTP API for the authoritative event store.
//
// It uses only net/http (no heavy framework) and supports protobuf and JSON
// content negotiation via Content-Type / Accept headers. Every pushed event is
// verified before storage by the underlying Store (verify-before-store).
package api

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

const (
	contentTypeProto = "application/x-protobuf"
	contentTypeJSON  = "application/json"

	// defaultMaxBodyBytes limits request bodies to guard against abuse.
	defaultMaxBodyBytes = 16 << 20 // 16 MiB
)

// Server is the HTTP API. It owns a Store and exposes the sync endpoints plus
// health checks.
type Server struct {
	store        store.Store
	maxBodyBytes int64
	// ready reports whether the server's dependencies are ready to serve. It
	// may be nil, in which case readiness is assumed.
	ready func(ctx context.Context) error
}

// Option configures a Server.
type Option func(*Server)

// WithMaxBodyBytes sets the maximum accepted request body size.
func WithMaxBodyBytes(n int64) Option {
	return func(s *Server) { s.maxBodyBytes = n }
}

// WithReadiness installs a readiness probe (e.g. a DB ping).
func WithReadiness(fn func(ctx context.Context) error) Option {
	return func(s *Server) { s.ready = fn }
}

// NewServer builds a Server over the given Store.
func NewServer(st store.Store, opts ...Option) *Server {
	s := &Server{store: st, maxBodyBytes: defaultMaxBodyBytes}
	for _, o := range opts {
		o(s)
	}
	return s
}

// Handler returns the http.Handler mounting all routes.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/events", s.handlePush)
	mux.HandleFunc("/v1/events/pull", s.handlePull)
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/readyz", s.handleReadyz)
	return mux
}

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", contentTypeJSON)
	w.WriteHeader(http.StatusOK)
	_, _ = io.WriteString(w, `{"status":"ok"}`)
}

func (s *Server) handleReadyz(w http.ResponseWriter, r *http.Request) {
	if s.ready != nil {
		if err := s.ready(r.Context()); err != nil {
			s.writeError(w, http.StatusServiceUnavailable, "not ready: "+err.Error())
			return
		}
	}
	w.Header().Set("Content-Type", contentTypeJSON)
	w.WriteHeader(http.StatusOK)
	_, _ = io.WriteString(w, `{"status":"ready"}`)
}

// handlePush implements POST /v1/events (PushEvents): verify each event, store
// the accepted ones, and return a PushEventsResponse carrying the Ack.
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

	applied, rejected, err := s.store.Push(r.Context(), req.GetEvents())
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "store push: "+err.Error())
		return
	}

	resp := &resiliencev1.PushEventsResponse{
		Ack: &resiliencev1.Ack{Applied: applied, Rejected: rejected},
	}
	s.writeMessage(w, r, resp, useJSON, http.StatusOK)
}

// handlePull implements GET/POST /v1/events/pull (PullEvents).
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
		from[store.AuthorKey(af.GetAuthorPubkey())] = af.GetFromLamport()
	}

	evs, err := s.store.PullByAuthorFrom(r.Context(), from, int(req.GetLimit()))
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

// decode reads the request body into msg, selecting protobuf or JSON based on
// the Content-Type header (defaulting to protobuf). It returns whether JSON was
// used so the response can mirror the request encoding. An empty body is
// tolerated (yields a zero-value message), which lets GET pulls with no body
// return everything.
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

// writeMessage serializes msg as JSON or protobuf. JSON is used when the
// request was JSON or the client's Accept header asks for it.
func (s *Server) writeMessage(w http.ResponseWriter, r *http.Request, msg proto.Message, reqWasJSON bool, status int) {
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
		s.writeError(w, http.StatusInternalServerError, "encode response: "+err.Error())
		return
	}
	w.Header().Set("Content-Type", ct)
	w.WriteHeader(status)
	_, _ = w.Write(out)
}

func (s *Server) writeError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", contentTypeJSON)
	w.WriteHeader(status)
	// Minimal structured error.
	_, _ = io.WriteString(w, fmt.Sprintf(`{"error":%q}`, msg))
}

func isJSON(contentType string) bool {
	// Match application/json (optionally with parameters like charset).
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

// ErrNoStore is returned when a Server is constructed without a Store.
var ErrNoStore = errors.New("api: server requires a non-nil store")
