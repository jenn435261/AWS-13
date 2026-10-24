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
	"strings"
	"time"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/cache"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

const (
	contentTypeProto = "application/x-protobuf"
	contentTypeJSON  = "application/json"

	defaultMaxBodyBytes = 16 << 20 // 16 MiB

	// maxBlobBytes caps a single encrypted attachment blob (ciphertext).
	maxBlobBytes = 2 << 20 // 2 MiB

	// blobTTL is how long an encrypted blob is retained before purge.
	blobTTL = 7 * 24 * time.Hour

	// blobRateLimit is the max blob writes per caller per blobRateWindow.
	blobRateLimit  = 120
	blobRateWindow = time.Minute
)

// Server wires the sync endpoints over a Cache.
type Server struct {
	cache        *cache.Cache
	maxBodyBytes int64

	// blobs holds opaque, content-addressed encrypted attachment blobs. The
	// node only ever sees ciphertext. blobLimiter rate limits writes.
	blobs        *blobStore
	blobLimiter  *rateLimiter
	maxBlobBytes int64
}

// New returns a sync Server backed by the given cache.
func New(c *cache.Cache) *Server {
	return &Server{
		cache:        c,
		maxBodyBytes: defaultMaxBodyBytes,
		blobs:        newBlobStore(blobTTL),
		blobLimiter:  newRateLimiter(blobRateLimit, blobRateWindow),
		maxBlobBytes: maxBlobBytes,
	}
}

// Register mounts the sync endpoints on mux. The web app ("/") and the package
// server are mounted separately by the daemon.
func (s *Server) Register(mux *http.ServeMux) {
	mux.HandleFunc("/node/v1/push", s.handlePush)
	mux.HandleFunc("/node/v1/pull", s.handlePull)
	mux.HandleFunc("/node/v1/have", s.handleHave)
	mux.HandleFunc("/node/v1/blobs/", s.handleBlob)
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

// handleBlob implements PUT/GET /node/v1/blobs/{sha256}: a content-addressed
// store for opaque, end-to-end-encrypted attachment blobs served over local
// Wi-Fi. The node only ever sees ciphertext; the decryption key rides inside
// the E2E message and never reaches here. The {sha256} path segment is the
// lowercase hex SHA-256 of the stored bytes and is verified on PUT so the
// address always matches its content. A 2 MiB cap, a per-caller rate limit,
// and a 7-day purge guard against abuse.
func (s *Server) handleBlob(w http.ResponseWriter, r *http.Request) {
	hash := strings.TrimPrefix(r.URL.Path, "/node/v1/blobs/")
	if !isHexSHA256(hash) {
		s.writeError(w, http.StatusBadRequest, "blob id must be a hex sha256")
		return
	}
	switch r.Method {
	case http.MethodPut, http.MethodPost:
		if !s.blobLimiter.allow(blobCaller(r)) {
			s.writeError(w, http.StatusTooManyRequests, "blob rate limit exceeded")
			return
		}
		data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, s.maxBlobBytes))
		if err != nil {
			s.writeError(w, http.StatusRequestEntityTooLarge, "blob exceeds size cap")
			return
		}
		if _, ok := s.blobs.put(hash, data); !ok {
			s.writeError(w, http.StatusBadRequest, "blob content does not match sha256")
			return
		}
		w.Header().Set("Content-Type", contentTypeJSON)
		w.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(w, fmt.Sprintf(`{"sha256":%q,"size":%d}`, hash, len(data)))
	case http.MethodGet:
		data, ok := s.blobs.get(hash)
		if !ok {
			s.writeError(w, http.StatusNotFound, "blob not found")
			return
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(data)
	default:
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

// isHexSHA256 reports whether s is exactly 64 lowercase hex characters.
func isHexSHA256(s string) bool {
	if len(s) != 64 {
		return false
	}
	for i := 0; i < len(s); i++ {
		c := s[i]
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
}

// blobCaller identifies the rate-limit bucket by the caller's host (the port
// changes per TCP connection, so we strip it).
func blobCaller(r *http.Request) string {
	addr := r.RemoteAddr
	if i := strings.LastIndex(addr, ":"); i >= 0 {
		addr = addr[:i]
	}
	return addr
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
