// Package gateway is the node's optional bridge to the wider network: an
// upstream cloud (over HTTP) and, in a future wave, a LoRa mesh. Both sit
// behind small interfaces so the daemon can run fully offline (nil/disabled
// bridges are no-ops) and so the sync logic is testable with fakes.
//
// When a cloud base URL is configured, the gateway periodically:
//   - pushes local events the cloud has not acknowledged yet, and
//   - pulls remote events (above the node's per-author watermarks) and stores
//     them locally.
//
// A disabled gateway (empty base URL) never touches the network; the node
// keeps serving phones over local Wi-Fi exactly as before.
package gateway

import (
	"bytes"
	"context"
	"encoding/hex"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/cache"
	"google.golang.org/protobuf/proto"
)

func hexDecode(s string) ([]byte, error) { return hex.DecodeString(s) }

// CloudClient is the minimal upstream API the gateway depends on. The real
// implementation talks to the cloud's /v1/events (push) and /v1/events/pull
// (pull) endpoints over HTTP; tests supply a fake.
type CloudClient interface {
	// Push uploads events to the cloud and returns the applied/rejected ids.
	Push(ctx context.Context, evs []*resiliencev1.SignedEvent) (applied [][]byte, rejected [][]byte, err error)
	// Pull returns events above the given per-author watermark (hex author key
	// -> from_lamport). An empty map means "everything".
	Pull(ctx context.Context, from map[string]uint64) ([]*resiliencev1.SignedEvent, error)
}

// MeshBridge is the interface a mesh transport (e.g. Wave-7 LoRa) implements so
// the daemon can bridge events over radio. It is a real, used interface: the
// daemon wires a MeshBridge into the gateway loop, defaulting to NopMesh when
// no radio is present. Implementations deliver inbound packets by calling the
// provided deliver callback, and accept outbound events via Broadcast.
type MeshBridge interface {
	// Start begins pumping inbound mesh events to deliver until ctx is done.
	// deliver is called with each received event; the gateway verifies+stores
	// it through the cache (which enforces verify-before-store).
	Start(ctx context.Context, deliver func(ev *resiliencev1.SignedEvent)) error
	// Broadcast queues an event for transmission over the mesh.
	Broadcast(ctx context.Context, ev *resiliencev1.SignedEvent) error
	// Name identifies the transport for logs.
	Name() string
}

// NopMesh is the default MeshBridge used until a real radio transport is
// plugged in.
//
// WAVE-7 LoRa INTEGRATION POINT: replace NopMesh with a LoRa-backed MeshBridge
// (e.g. a serial/SPI radio driver) and wire it into Options.Mesh. The gateway
// loop already calls Start (inbound) and Broadcast (outbound), so no other
// code changes are required to light up mesh sync.
type NopMesh struct{}

// Start blocks until ctx is cancelled and delivers nothing.
func (NopMesh) Start(ctx context.Context, _ func(ev *resiliencev1.SignedEvent)) error {
	<-ctx.Done()
	return ctx.Err()
}

// Broadcast is a no-op.
func (NopMesh) Broadcast(context.Context, *resiliencev1.SignedEvent) error { return nil }

// Name returns the transport name.
func (NopMesh) Name() string { return "nop-mesh" }

var _ MeshBridge = NopMesh{}

// Options configures a Gateway.
type Options struct {
	// Cloud is the upstream client. When nil the cloud bridge is disabled.
	Cloud CloudClient
	// Mesh is the mesh transport. When nil NopMesh is used.
	Mesh MeshBridge
	// Interval is the sync cadence; defaults to 15s when <= 0.
	Interval time.Duration
	// Logger is used for structured logs; defaults to slog.Default().
	Logger *slog.Logger
}

// Gateway bridges a local cache to the cloud and/or mesh.
type Gateway struct {
	cache  *cache.Cache
	cloud  CloudClient
	mesh   MeshBridge
	every  time.Duration
	log    *slog.Logger
	cursor uint64 // high-water of local events already pushed to the cloud
}

// New builds a Gateway over the cache with the given options.
func New(c *cache.Cache, opts Options) *Gateway {
	g := &Gateway{
		cache: c,
		cloud: opts.Cloud,
		mesh:  opts.Mesh,
		every: opts.Interval,
		log:   opts.Logger,
	}
	if g.mesh == nil {
		g.mesh = NopMesh{}
	}
	if g.every <= 0 {
		g.every = 15 * time.Second
	}
	if g.log == nil {
		g.log = slog.Default()
	}
	return g
}

// Enabled reports whether any upstream bridge is active. When false the gateway
// loop does nothing beyond running the (no-op) mesh.
func (g *Gateway) Enabled() bool { return g.cloud != nil }

// Run drives the gateway until ctx is cancelled. It starts the mesh inbound
// pump and, when a cloud client is configured, ticks a push/pull sync loop.
// Run always returns nil on clean shutdown.
func (g *Gateway) Run(ctx context.Context) error {
	// Mesh inbound pump: deliver received events into the cache (verified there).
	go func() {
		err := g.mesh.Start(ctx, func(ev *resiliencev1.SignedEvent) {
			if _, _, perr := g.cache.Push(ctx, []*resiliencev1.SignedEvent{ev}); perr != nil {
				g.log.Warn("mesh deliver store failed", "transport", g.mesh.Name(), "err", perr)
			}
		})
		if err != nil && ctx.Err() == nil {
			g.log.Warn("mesh stopped", "transport", g.mesh.Name(), "err", err)
		}
	}()

	if g.cloud == nil {
		g.log.Info("cloud gateway disabled; serving locally only")
		<-ctx.Done()
		return nil
	}

	g.log.Info("cloud gateway enabled", "interval", g.every.String())
	ticker := time.NewTicker(g.every)
	defer ticker.Stop()

	// Sync once promptly, then on each tick.
	g.syncOnce(ctx)
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			g.syncOnce(ctx)
		}
	}
}

// SyncOnce runs a single push+pull cycle. Exported for tests and for manual
// triggering.
func (g *Gateway) SyncOnce(ctx context.Context) error { return g.syncOnce(ctx) }

func (g *Gateway) syncOnce(ctx context.Context) error {
	if g.cloud == nil {
		return nil
	}
	// Push: upload local events whose lamport is above the cursor we last
	// pushed. We use a single synthetic watermark across all authors keyed by
	// lamport via PullAbove(nil) and filter by cursor for simplicity and
	// determinism in the hackathon node.
	local, err := g.cache.All(ctx)
	if err != nil {
		return err
	}
	var toPush []*resiliencev1.SignedEvent
	var maxLamport uint64
	for _, ev := range local {
		l := ev.GetHeader().GetLamport()
		if l > maxLamport {
			maxLamport = l
		}
		if l > g.cursor {
			toPush = append(toPush, ev)
		}
	}
	if len(toPush) > 0 {
		if _, _, err := g.cloud.Push(ctx, toPush); err != nil {
			g.log.Warn("cloud push failed", "err", err)
		} else {
			g.cursor = maxLamport
			g.log.Info("pushed events to cloud", "count", len(toPush))
			// Mirror upstream over the mesh too (no-op by default).
			for _, ev := range toPush {
				_ = g.mesh.Broadcast(ctx, ev)
			}
		}
	}

	// Pull: ask the cloud for events above our per-author watermarks and store
	// them (the cache verifies before storing).
	from, err := g.cache.HighWaterByAuthor(ctx)
	if err != nil {
		return err
	}
	remote, err := g.cloud.Pull(ctx, from)
	if err != nil {
		g.log.Warn("cloud pull failed", "err", err)
		return nil
	}
	if len(remote) > 0 {
		applied, rejected, perr := g.cache.Push(ctx, remote)
		if perr != nil {
			return perr
		}
		g.log.Info("pulled events from cloud", "applied", len(applied), "rejected", len(rejected))
	}
	return nil
}

// --- real HTTP cloud client ---

// HTTPCloud is a CloudClient that talks protobuf to the cloud API's
// /v1/events (push) and /v1/events/pull (pull) endpoints.
type HTTPCloud struct {
	BaseURL string
	Client  *http.Client
}

// NewHTTPCloud returns an HTTPCloud for baseURL with a sane default timeout.
func NewHTTPCloud(baseURL string) *HTTPCloud {
	return &HTTPCloud{
		BaseURL: trimSlash(baseURL),
		Client:  &http.Client{Timeout: 30 * time.Second},
	}
}

var _ CloudClient = (*HTTPCloud)(nil)

// Push implements CloudClient.
func (h *HTTPCloud) Push(ctx context.Context, evs []*resiliencev1.SignedEvent) ([][]byte, [][]byte, error) {
	req := &resiliencev1.PushEventsRequest{Events: evs}
	body, err := proto.Marshal(req)
	if err != nil {
		return nil, nil, err
	}
	respBytes, err := h.post(ctx, h.BaseURL+"/v1/events", body)
	if err != nil {
		return nil, nil, err
	}
	resp := &resiliencev1.PushEventsResponse{}
	if err := proto.Unmarshal(respBytes, resp); err != nil {
		return nil, nil, err
	}
	return resp.GetAck().GetApplied(), resp.GetAck().GetRejected(), nil
}

// Pull implements CloudClient.
func (h *HTTPCloud) Pull(ctx context.Context, from map[string]uint64) ([]*resiliencev1.SignedEvent, error) {
	req := &resiliencev1.PullEventsRequest{}
	for authorHex, lamport := range from {
		pub, err := hexDecode(authorHex)
		if err != nil {
			continue
		}
		req.From = append(req.From, &resiliencev1.PullEventsRequest_AuthorFrom{
			AuthorPubkey: pub,
			FromLamport:  lamport,
		})
	}
	body, err := proto.Marshal(req)
	if err != nil {
		return nil, err
	}
	respBytes, err := h.post(ctx, h.BaseURL+"/v1/events/pull", body)
	if err != nil {
		return nil, err
	}
	resp := &resiliencev1.PullEventsResponse{}
	if err := proto.Unmarshal(respBytes, resp); err != nil {
		return nil, err
	}
	return resp.GetBatch().GetEvents(), nil
}

func (h *HTTPCloud) post(ctx context.Context, url string, body []byte) ([]byte, error) {
	client := h.Client
	if client == nil {
		client = http.DefaultClient
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-protobuf")
	req.Header.Set("Accept", "application/x-protobuf")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("cloud returned %d: %s", resp.StatusCode, string(out))
	}
	return out, nil
}

func trimSlash(s string) string {
	for len(s) > 0 && s[len(s)-1] == '/' {
		s = s[:len(s)-1]
	}
	return s
}
