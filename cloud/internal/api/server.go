// Package api implements the slim HTTP API for the authoritative event store.
//
// It uses only net/http (no heavy framework) and supports protobuf and JSON
// content negotiation via Content-Type / Accept headers. Every pushed event is
// verified before storage by the underlying Store (verify-before-store).
package api

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/ai"
	"github.com/resilience-network/aws13/cloud/internal/org"
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

	// online is the AI assistant for the online path (Bedrock). It is nil when
	// BEDROCK_MODEL_ID is unset, in which case the API serves only the
	// deterministic rules path. When non-nil, a Bedrock error falls back to
	// rules.
	online ai.Assistant
	// rules is the always-available deterministic fallback assistant.
	rules ai.Assistant

	// aggregator computes aggregate, consent-respecting org need-by-cell data.
	aggregator *org.Aggregator
	// orgTokens is the set of valid X-Org-Token values (the hackathon-simple
	// stand-in for a verified-org certificate). When empty, token auth is
	// rejected and only a verified-org path (if any) could pass.
	orgTokens map[string]struct{}
	// trustedOrgs recognizes verified-org signing keys (ORG_TRUSTED_PUBKEYS).
	trustedOrgs *org.TrustedOrgs
	// clientTokens is the set of valid X-Api-Key values for the sync and AI
	// routes (CLIENT_API_KEYS). When empty those routes are open.
	clientTokens map[string]struct{}
	// webKey is the first client token, handed to the bundled web app via
	// /app-config.json. webDir is the Flutter web bundle directory (see web.go).
	webKey string
	webDir string
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

// WithOnlineAssistant installs the online AI assistant (Bedrock). When set,
// AI endpoints try it first and fall back to the deterministic rules path on
// error. When nil (the default), only the rules path is used.
func WithOnlineAssistant(a ai.Assistant) Option {
	return func(s *Server) { s.online = a }
}

// WithRulesAssistant overrides the deterministic fallback assistant (mainly for
// tests). By default a fresh ai.RulesAssistant is used.
func WithRulesAssistant(a ai.Assistant) Option {
	return func(s *Server) { s.rules = a }
}

// WithOrgTokens installs the set of valid X-Org-Token values (the
// hackathon-simple stand-in for a verified-org certificate). In production this
// maps to the verified-org cert; the token is the stand-in. Tokens are compared
// in constant time.
func WithOrgTokens(tokens []string) Option {
	return func(s *Server) {
		s.orgTokens = make(map[string]struct{}, len(tokens))
		for _, t := range tokens {
			t = strings.TrimSpace(t)
			if t == "" {
				continue
			}
			s.orgTokens[t] = struct{}{}
		}
	}
}

// WithClientTokens gates /v1/events, /v1/events/pull and /v1/ai/* behind a
// shared X-Api-Key (or "Authorization: Bearer") token. It is an abuse guard for
// a public deployment, not user authentication: a key shipped inside an app can
// be extracted. Health checks and the org API (own token) are unaffected.
func WithClientTokens(tokens []string) Option {
	return func(s *Server) {
		s.clientTokens = make(map[string]struct{}, len(tokens))
		for _, t := range tokens {
			if t = strings.TrimSpace(t); t != "" {
				s.clientTokens[t] = struct{}{}
				if s.webKey == "" {
					s.webKey = t
				}
			}
		}
	}
}

// WithTrustedOrgs installs the verified-org signing-key set used to validate
// and tag EMERGENCY_ALERT events (ORG_TRUSTED_PUBKEYS).
func WithTrustedOrgs(t *org.TrustedOrgs) Option {
	return func(s *Server) { s.trustedOrgs = t }
}

// NewServer builds a Server over the given Store.
func NewServer(st store.Store, opts ...Option) *Server {
	s := &Server{store: st, maxBodyBytes: defaultMaxBodyBytes}
	for _, o := range opts {
		o(s)
	}
	if s.rules == nil {
		s.rules = ai.NewRulesAssistant()
	}
	if s.aggregator == nil && st != nil {
		s.aggregator = org.NewAggregator(st)
	}
	return s
}

// Handler returns the http.Handler mounting all routes.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/events", s.clientGate(s.handlePush))
	mux.HandleFunc("/v1/events/pull", s.clientGate(s.handlePull))
	mux.HandleFunc("/v1/ai/structure", s.clientGate(s.handleAIStructure))
	mux.HandleFunc("/v1/ai/translate", s.clientGate(s.handleAITranslate))
	mux.HandleFunc("/v1/ai/summarize", s.clientGate(s.handleAISummarize))
	mux.HandleFunc("/v1/ai/dedup", s.clientGate(s.handleAIDedup))
	mux.HandleFunc("/v1/org/needs", s.handleOrgNeeds)
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/readyz", s.handleReadyz)
	s.mountWeb(mux)
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

// --- AI assist endpoints ---
//
// Each endpoint uses plain JSON (not protobuf): the AI payloads are simple and
// the Dart BedrockAiClient talks to these over HTTP with the http package. The
// contract: try the online assistant (Bedrock) if configured; on any error
// fall back to the deterministic rules assistant; ALWAYS return 200 with a
// "degraded" flag so the emergency system never fails because AI is down.

// decodeAIJSON reads a JSON request body into v, enforcing the body size limit.
func (s *Server) decodeAIJSON(r *http.Request, v any) error {
	body, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, s.maxBodyBytes))
	if err != nil {
		return fmt.Errorf("read body: %w", err)
	}
	if len(body) == 0 {
		return nil
	}
	if err := json.Unmarshal(body, v); err != nil {
		return err
	}
	return nil
}

// writeAIJSON writes v as a 200 JSON response.
func (s *Server) writeAIJSON(w http.ResponseWriter, v any) {
	out, err := json.Marshal(v)
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "encode response: "+err.Error())
		return
	}
	w.Header().Set("Content-Type", contentTypeJSON)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(out)
}

// aiStructureResponse mirrors ai.StructuredReport plus the degraded flag.
type aiStructureResponse struct {
	Category       string `json:"category"`
	Priority       string `json:"priority"`
	ShortTitle     string `json:"short_title"`
	NormalizedNote string `json:"normalized_note"`
	Degraded       bool   `json:"degraded"`
}

func (s *Server) handleAIStructure(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var req struct {
		Text     string `json:"text"`
		LangHint string `json:"lang_hint"`
	}
	if err := s.decodeAIJSON(r, &req); err != nil {
		s.writeError(w, http.StatusBadRequest, "decode request: "+err.Error())
		return
	}

	degraded := true
	var res ai.StructuredReport
	if s.online != nil {
		if out, err := s.online.Structure(r.Context(), req.Text, req.LangHint); err == nil {
			res, degraded = out, false
		}
	}
	if degraded {
		// Fallback never errors.
		res, _ = s.rules.Structure(r.Context(), req.Text, req.LangHint)
	}

	s.writeAIJSON(w, aiStructureResponse{
		Category:       res.Category,
		Priority:       string(res.Priority),
		ShortTitle:     res.ShortTitle,
		NormalizedNote: res.NormalizedNote,
		Degraded:       degraded,
	})
}

type aiTranslateResponse struct {
	Text       string `json:"text"`
	From       string `json:"from"`
	To         string `json:"to"`
	Translated bool   `json:"translated"`
	Degraded   bool   `json:"degraded"`
}

func (s *Server) handleAITranslate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var req struct {
		Text string `json:"text"`
		From string `json:"from"`
		To   string `json:"to"`
	}
	if err := s.decodeAIJSON(r, &req); err != nil {
		s.writeError(w, http.StatusBadRequest, "decode request: "+err.Error())
		return
	}

	degraded := true
	var res ai.Translation
	if s.online != nil {
		if out, err := s.online.Translate(r.Context(), req.Text, req.From, req.To); err == nil {
			res, degraded = out, false
		}
	}
	if degraded {
		res, _ = s.rules.Translate(r.Context(), req.Text, req.From, req.To)
	}

	s.writeAIJSON(w, aiTranslateResponse{
		Text:       res.Text,
		From:       res.From,
		To:         res.To,
		Translated: res.Translated,
		Degraded:   degraded,
	})
}

type aiSummarizeResponse struct {
	Summary  string `json:"summary"`
	Degraded bool   `json:"degraded"`
}

func (s *Server) handleAISummarize(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var req struct {
		Items []string `json:"items"`
	}
	if err := s.decodeAIJSON(r, &req); err != nil {
		s.writeError(w, http.StatusBadRequest, "decode request: "+err.Error())
		return
	}

	degraded := true
	var summary string
	if s.online != nil {
		if out, err := s.online.Summarize(r.Context(), req.Items); err == nil {
			summary, degraded = out, false
		}
	}
	if degraded {
		summary, _ = s.rules.Summarize(r.Context(), req.Items)
	}

	s.writeAIJSON(w, aiSummarizeResponse{Summary: summary, Degraded: degraded})
}

type aiDedupResponse struct {
	Hits     []ai.DupHit `json:"hits"`
	Degraded bool        `json:"degraded"`
}

func (s *Server) handleAIDedup(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var req struct {
		Candidate string   `json:"candidate"`
		Existing  []string `json:"existing"`
	}
	if err := s.decodeAIJSON(r, &req); err != nil {
		s.writeError(w, http.StatusBadRequest, "decode request: "+err.Error())
		return
	}

	degraded := true
	var hits []ai.DupHit
	if s.online != nil {
		if out, err := s.online.Dedup(r.Context(), req.Candidate, req.Existing); err == nil {
			hits, degraded = out, false
		}
	}
	if degraded {
		hits, _ = s.rules.Dedup(r.Context(), req.Candidate, req.Existing)
	}
	if hits == nil {
		hits = []ai.DupHit{}
	}

	s.writeAIJSON(w, aiDedupResponse{Hits: hits, Degraded: degraded})
}

// --- Org / first-responder integration (aggregate, consent-respecting) ---
//
// GET/POST /v1/org/needs returns ONLY aggregate need-by-H3-cell data:
// {"cells":[{"h3_cell","category","count"}],"generated_at","window_ms"}. It
// NEVER exposes individual authors, exact coordinates, message contents, or any
// location-share payload. The endpoint is gated behind an org capability check:
// a header X-Org-Token matching a configured token (ORG_API_TOKENS) OR a
// verified-org request. Absent/invalid credentials return 401.

// orgNeedsRequest is the optional JSON request body for /v1/org/needs.
type orgNeedsRequest struct {
	Cells         []uint64 `json:"cells"`
	WindowMs      int64    `json:"window_ms"`
	NowMs         int64    `json:"now_ms"`
	IncludeOffers bool     `json:"include_offers"`
}

func (s *Server) handleOrgNeeds(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if !s.orgAuthorized(r) {
		s.writeError(w, http.StatusUnauthorized, "org authorization required")
		return
	}
	if s.aggregator == nil {
		s.writeError(w, http.StatusServiceUnavailable, "aggregator unavailable")
		return
	}

	q := org.Query{}
	// Accept a JSON body (POST) or query params (GET) for the aggregation
	// bounds; both are optional.
	if r.Method == http.MethodPost {
		var req orgNeedsRequest
		if err := s.decodeAIJSON(r, &req); err != nil {
			s.writeError(w, http.StatusBadRequest, "decode request: "+err.Error())
			return
		}
		q.Cells = req.Cells
		q.WindowMs = req.WindowMs
		q.NowMs = req.NowMs
		q.IncludeOffers = req.IncludeOffers
	} else {
		q = parseNeedsQuery(r)
	}

	report, err := s.aggregator.Needs(r.Context(), q)
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "aggregate: "+err.Error())
		return
	}
	// The report is aggregate-only by construction (see package org): no author,
	// no exact coordinate, no message content ever appears here.
	s.writeAIJSON(w, report)
}

// clientGate rejects requests lacking a valid client key when CLIENT_API_KEYS
// is configured; with no keys configured it is a pass-through.
func (s *Server) clientGate(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if len(s.clientTokens) > 0 && !s.clientAuthorized(r) {
			s.writeError(w, http.StatusUnauthorized, "api key required")
			return
		}
		next(w, r)
	}
}

func (s *Server) clientAuthorized(r *http.Request) bool {
	token := strings.TrimSpace(r.Header.Get("X-Api-Key"))
	if token == "" {
		if a := r.Header.Get("Authorization"); strings.HasPrefix(a, "Bearer ") {
			token = strings.TrimSpace(a[len("Bearer "):])
		}
	}
	if token == "" {
		return false
	}
	ok := false
	for valid := range s.clientTokens {
		if subtle.ConstantTimeCompare([]byte(token), []byte(valid)) == 1 {
			ok = true
		}
	}
	return ok
}

// orgAuthorized gates the org endpoints: a valid X-Org-Token (constant-time
// compared against the configured set) grants access. This is the
// hackathon-simple stand-in for a verified-org certificate; in production the
// same gate maps to the verified-org cert chain.
func (s *Server) orgAuthorized(r *http.Request) bool {
	token := strings.TrimSpace(r.Header.Get("X-Org-Token"))
	if token == "" || len(s.orgTokens) == 0 {
		return false
	}
	for valid := range s.orgTokens {
		if subtle.ConstantTimeCompare([]byte(token), []byte(valid)) == 1 {
			return true
		}
	}
	return false
}

// parseNeedsQuery reads aggregation bounds from GET query params: repeated
// ?cell= (uint64), ?window_ms=, ?now_ms=, ?include_offers=true.
func parseNeedsQuery(r *http.Request) org.Query {
	q := org.Query{}
	for _, c := range r.URL.Query()["cell"] {
		if v, err := strconv.ParseUint(c, 10, 64); err == nil {
			q.Cells = append(q.Cells, v)
		}
	}
	if v, err := strconv.ParseInt(r.URL.Query().Get("window_ms"), 10, 64); err == nil {
		q.WindowMs = v
	}
	if v, err := strconv.ParseInt(r.URL.Query().Get("now_ms"), 10, 64); err == nil {
		q.NowMs = v
	}
	if v, err := strconv.ParseBool(r.URL.Query().Get("include_offers")); err == nil {
		q.IncludeOffers = v
	}
	return q
}

// ErrNoStore is returned when a Server is constructed without a Store.
var ErrNoStore = errors.New("api: server requires a non-nil store")
