// Package lora is the node-side LoRa / Meshtastic gateway (spec §6.3b).
//
// NEEDS REAL HARDWARE to run against a radio: a Meshtastic device (Heltec V3,
// LilyGO T-Beam, RAK4631, ...) connected over serial/USB. The serial read is
// hidden behind the FrameSource interface so the decode -> verify -> store ->
// rebroadcast pipeline is fully testable from a canned byte stream (an
// io.Reader) with no device present.
//
// Wire format (must stay byte-identical to app/lib/transport/lora_codec.dart):
//
//	magic 'L' (0x4c) | version (1) | msgId (2, big-endian) | fragIndex (1) |
//	fragCount (1) | bodyLen (1) | body[bodyLen]
//
// The node reads fragments, reassembles them by msgId (out-of-order and
// duplicate tolerant), dedupes whole events by event id, verifies each
// reassembled SignedEvent (Ed25519 + BLAKE2b content hash) BEFORE storing, and
// rebroadcasts newly-stored SOS / emergency-alert events back out to the mesh
// so a phone with no internet can reach a node with internet through the hops.
//
// Deployment: set the radio's region/frequency (US915, EU868, ...) correctly —
// the wrong band is illegal and will not interoperate. The Meshtastic channel
// PSK is kept out of git and distributed out-of-band; the app's end-to-end
// event signing is independent of and layered above that channel crypto.
package lora

import (
	"context"
	"encoding/binary"
	"encoding/hex"
	"io"
	"log/slog"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/events"
	"google.golang.org/protobuf/proto"
)

const (
	magic      = 0x4c // 'L'
	version    = 1
	headerLen  = 7
	maxBody    = 215 // maxFragmentBytes(222) - headerLen(7)
	maxFrags   = 255
	maxPayload = maxBody * maxFrags
)

// Store is the subset of the node cache the gateway needs: verify-before-store
// Push and content-hash dedup are provided by the cache implementation.
type Store interface {
	Push(ctx context.Context, evs []*resiliencev1.SignedEvent) (applied [][]byte, rejected [][]byte, err error)
}

// FrameSource yields raw LoRa fragments heard on the mesh. A real
// implementation wraps a Meshtastic serial device; tests use a canned reader.
type FrameSource interface {
	// Next blocks until the next fragment is available, returning io.EOF when
	// the source is exhausted.
	Next(ctx context.Context) ([]byte, error)
	Close() error
}

// FrameSink sends a raw LoRa fragment out to the mesh (rebroadcast).
type FrameSink interface {
	Send(ctx context.Context, frame []byte) error
}

// Gateway decodes, verifies, stores, and rebroadcasts LoRa events.
type Gateway struct {
	store  Store
	sink   FrameSink // optional; nil disables rebroadcast
	logger *slog.Logger

	re        *Reassembler
	msgOut    uint16
	delivered map[string]struct{} // event id hex already stored/seen
}

// New builds a gateway. sink may be nil to disable rebroadcast. logger may be
// nil (a no-op logger is used).
func New(store Store, sink FrameSink, logger *slog.Logger) *Gateway {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &Gateway{
		store:     store,
		sink:      sink,
		logger:    logger,
		re:        NewReassembler(64),
		delivered: make(map[string]struct{}),
	}
}

// Run pumps fragments from src until the context is cancelled or src returns
// io.EOF. Each reassembled, verified event is stored; new SOS/alert events are
// rebroadcast if a sink is configured. Returns the number of events stored.
func (g *Gateway) Run(ctx context.Context, src FrameSource) (int, error) {
	stored := 0
	for {
		if ctx.Err() != nil {
			return stored, ctx.Err()
		}
		frame, err := src.Next(ctx)
		if err != nil {
			if err == io.EOF {
				return stored, nil
			}
			return stored, err
		}
		n, serr := g.ingestFrame(ctx, frame)
		if serr != nil {
			return stored, serr
		}
		stored += n
	}
}

// ingestFrame feeds one raw fragment. Returns the number of events newly
// stored (0 or 1).
func (g *Gateway) ingestFrame(ctx context.Context, frame []byte) (int, error) {
	payload, ok := g.re.Add(frame)
	if !ok {
		return 0, nil // incomplete, duplicate, or malformed fragment
	}
	ev := &resiliencev1.SignedEvent{}
	if err := proto.Unmarshal(payload, ev); err != nil {
		g.logger.Warn("lora: dropping un-parseable payload")
		return 0, nil
	}
	// Dedup by event id across reassembled messages.
	idKey := hex.EncodeToString(ev.GetHeader().GetEventId())
	if idKey != "" {
		if _, seen := g.delivered[idKey]; seen {
			return 0, nil
		}
	}
	// Verify-before-store: the cache re-verifies, but we also reject here so a
	// forged frame never advances dedupe state or triggers a rebroadcast.
	if ok, reason := events.VerifyEvent(ev); !ok {
		g.logger.Warn("lora: rejecting forged/invalid event", "reason", reason)
		return 0, nil
	}
	applied, _, err := g.store.Push(ctx, []*resiliencev1.SignedEvent{ev})
	if err != nil {
		return 0, err
	}
	if idKey != "" {
		g.delivered[idKey] = struct{}{}
	}
	if len(applied) == 0 {
		return 0, nil // duplicate at the store layer
	}
	// Rebroadcast new SOS / emergency alerts so they propagate across the mesh.
	if g.sink != nil && shouldRebroadcast(ev.GetHeader().GetType()) {
		g.rebroadcast(ctx, ev)
	}
	return 1, nil
}

func (g *Gateway) rebroadcast(ctx context.Context, ev *resiliencev1.SignedEvent) {
	payload, err := proto.Marshal(ev)
	if err != nil {
		return
	}
	g.msgOut++
	frames, ferr := FragmentPayload(payload, g.msgOut)
	if ferr != nil {
		g.logger.Warn("lora: cannot rebroadcast event", "err", ferr)
		return
	}
	for _, f := range frames {
		if err := g.sink.Send(ctx, f); err != nil {
			g.logger.Warn("lora: rebroadcast send failed", "err", err)
			return
		}
	}
}

// shouldRebroadcast returns true for the urgent event kinds the mesh should
// propagate onward.
func shouldRebroadcast(t resiliencev1.EventType) bool {
	switch t {
	case resiliencev1.EventType_EVENT_TYPE_HELP_REQUESTED,
		resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT:
		return true
	default:
		return false
	}
}

// --- fragment codec (mirror of the Dart LoraCodec) --------------------------

// Fragment is a parsed LoRa fragment.
type Fragment struct {
	MsgID uint16
	Index uint8
	Count uint8
	Body  []byte
}

// ParseFragment parses one raw fragment, returning ok=false if malformed.
func ParseFragment(frame []byte) (Fragment, bool) {
	if len(frame) < headerLen {
		return Fragment{}, false
	}
	if frame[0] != magic || frame[1] != version {
		return Fragment{}, false
	}
	msgID := binary.BigEndian.Uint16(frame[2:4])
	index := frame[4]
	count := frame[5]
	bodyLen := int(frame[6])
	if count == 0 || int(index) >= int(count) {
		return Fragment{}, false
	}
	if len(frame) != headerLen+bodyLen {
		return Fragment{}, false
	}
	body := make([]byte, bodyLen)
	copy(body, frame[headerLen:headerLen+bodyLen])
	return Fragment{MsgID: msgID, Index: index, Count: count, Body: body}, true
}

// FragmentPayload splits payload into LoRa frames under msgID.
func FragmentPayload(payload []byte, msgID uint16) ([][]byte, error) {
	if len(payload) == 0 {
		return nil, io.ErrUnexpectedEOF
	}
	if len(payload) > maxPayload {
		return nil, io.ErrShortBuffer
	}
	count := (len(payload) + maxBody - 1) / maxBody
	frames := make([][]byte, 0, count)
	for i := 0; i < count; i++ {
		start := i * maxBody
		end := start + maxBody
		if end > len(payload) {
			end = len(payload)
		}
		bodyLen := end - start
		f := make([]byte, headerLen+bodyLen)
		f[0] = magic
		f[1] = version
		binary.BigEndian.PutUint16(f[2:4], msgID)
		f[4] = uint8(i)
		f[5] = uint8(count)
		f[6] = uint8(bodyLen)
		copy(f[headerLen:], payload[start:end])
		frames = append(frames, f)
	}
	return frames, nil
}

// --- reassembler ------------------------------------------------------------

// Reassembler rebuilds payloads from fragments, out-of-order and duplicate
// tolerant, with whole-payload dedup by content fingerprint.
type Reassembler struct {
	maxPending int
	pending    map[uint16]*pending
	order      []uint16
	delivered  map[string]struct{}
}

// NewReassembler returns a reassembler tracking at most maxPending in-flight
// messages.
func NewReassembler(maxPending int) *Reassembler {
	if maxPending <= 0 {
		maxPending = 64
	}
	return &Reassembler{
		maxPending: maxPending,
		pending:    make(map[uint16]*pending),
		delivered:  make(map[string]struct{}),
	}
}

type pending struct {
	count uint8
	parts [][]byte
}

func (p *pending) complete() bool {
	for _, b := range p.parts {
		if b == nil {
			return false
		}
	}
	return true
}

func (p *pending) assemble() []byte {
	var out []byte
	for _, b := range p.parts {
		out = append(out, b...)
	}
	return out
}

// Add feeds one raw fragment. It returns the reassembled payload and ok=true
// when a message completes for the first time; otherwise ok=false.
func (r *Reassembler) Add(frame []byte) ([]byte, bool) {
	frag, ok := ParseFragment(frame)
	if !ok {
		return nil, false
	}
	p := r.pending[frag.MsgID]
	if p == nil {
		p = &pending{count: frag.Count, parts: make([][]byte, frag.Count)}
		r.pending[frag.MsgID] = p
		r.order = append(r.order, frag.MsgID)
		r.evict()
	}
	if frag.Count != p.count {
		return nil, false // conflicting count: ignore stray fragment
	}
	p.parts[frag.Index] = frag.Body
	if !p.complete() {
		return nil, false
	}
	payload := p.assemble()
	delete(r.pending, frag.MsgID)
	r.removeOrder(frag.MsgID)

	fp := fingerprint(payload)
	if _, seen := r.delivered[fp]; seen {
		return nil, false
	}
	r.delivered[fp] = struct{}{}
	return payload, true
}

func (r *Reassembler) evict() {
	for len(r.order) > r.maxPending {
		oldest := r.order[0]
		r.order = r.order[1:]
		delete(r.pending, oldest)
	}
}

func (r *Reassembler) removeOrder(id uint16) {
	for i, v := range r.order {
		if v == id {
			r.order = append(r.order[:i], r.order[i+1:]...)
			return
		}
	}
}

// fingerprint is FNV-1a 64-bit over the payload, matching the Dart dedup key
// semantics (cheap; the real identity check is VerifyEvent).
func fingerprint(b []byte) string {
	var h uint64 = 0xcbf29ce484222325
	const prime uint64 = 0x100000001b3
	for _, c := range b {
		h ^= uint64(c)
		h *= prime
	}
	buf := make([]byte, 8)
	binary.BigEndian.PutUint64(buf, h)
	return hex.EncodeToString(buf)
}
