package lora

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"sync"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"github.com/resilience-network/aws13/node/internal/cache"
	"github.com/resilience-network/aws13/node/internal/events"
	"google.golang.org/protobuf/proto"
)

func mustKey(t *testing.T) ed25519.PrivateKey {
	t.Helper()
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("key: %v", err)
	}
	return priv
}

func sosEvent(t *testing.T, priv ed25519.PrivateKey, lamport uint64, note string) *resiliencev1.SignedEvent {
	t.Helper()
	body, err := proto.Marshal(&resiliencev1.HelpRequestBody{Freeform: note})
	if err != nil {
		t.Fatalf("marshal body: %v", err)
	}
	h := &resiliencev1.EventHeader{
		Type:    resiliencev1.EventType_EVENT_TYPE_HELP_REQUESTED,
		Lamport: lamport,
	}
	ev, err := events.BuildSignedEvent(h, body, priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	return ev
}

// collectingSink records every rebroadcast frame.
type collectingSink struct {
	mu     sync.Mutex
	frames [][]byte
}

func (s *collectingSink) Send(ctx context.Context, frame []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.frames = append(s.frames, append([]byte(nil), frame...))
	return nil
}

func TestFragmentReassembleRoundTrip(t *testing.T) {
	payload := make([]byte, 900)
	for i := range payload {
		payload[i] = byte(i * 7)
	}
	frames, err := FragmentPayload(payload, 11)
	if err != nil {
		t.Fatalf("fragment: %v", err)
	}
	if len(frames) < 2 {
		t.Fatalf("expected multiple fragments, got %d", len(frames))
	}
	re := NewReassembler(8)
	var got []byte
	for _, f := range frames {
		if out, ok := re.Add(f); ok {
			got = out
		}
	}
	if !bytes.Equal(got, payload) {
		t.Fatalf("reassembled payload mismatch")
	}
}

func TestReassembleOutOfOrderAndDuplicate(t *testing.T) {
	payload := make([]byte, 700)
	for i := range payload {
		payload[i] = byte(i)
	}
	frames, _ := FragmentPayload(payload, 3)
	re := NewReassembler(8)
	completions := 0
	// Reverse order, each delivered twice.
	for i := len(frames) - 1; i >= 0; i-- {
		if _, ok := re.Add(frames[i]); ok {
			completions++
		}
		if _, ok := re.Add(frames[i]); ok {
			completions++
		}
	}
	if completions != 1 {
		t.Fatalf("expected exactly one completion, got %d", completions)
	}
}

func TestGatewayIngestsCannedSerialStream(t *testing.T) {
	priv := mustKey(t)
	a := sosEvent(t, priv, 1, "need water at the shelter")
	b := sosEvent(t, priv, 2, "injured person, 3rd and Main")

	pa, _ := proto.Marshal(a)
	pb, _ := proto.Marshal(b)
	fa, _ := FragmentPayload(pa, 1)
	fb, _ := FragmentPayload(pb, 2)

	// Canned serial stream: all of a's fragments, then b's, plus a duplicate of
	// a's first fragment interleaved (mesh rebroadcast noise).
	var all [][]byte
	all = append(all, fa...)
	all = append(all, fa[0]) // duplicate fragment
	all = append(all, fb...)
	stream := EncodeStream(all)

	store := cache.New()
	sink := &collectingSink{}
	gw := New(store, sink, nil)

	src := NewStreamSource(bytes.NewReader(stream))
	stored, err := gw.Run(context.Background(), src)
	if err != nil {
		t.Fatalf("run: %v", err)
	}
	if stored != 2 {
		t.Fatalf("expected 2 stored events, got %d", stored)
	}
	if store.Len() != 2 {
		t.Fatalf("expected cache len 2, got %d", store.Len())
	}
	// Both SOS events should have been rebroadcast (at least 2 frames).
	if len(sink.frames) < 2 {
		t.Fatalf("expected rebroadcast frames, got %d", len(sink.frames))
	}
}

func TestGatewayRejectsForgedFrame(t *testing.T) {
	priv := mustKey(t)
	ev := sosEvent(t, priv, 1, "legit")
	ev.Body = []byte("tampered") // invalidate signature/hash

	payload, _ := proto.Marshal(ev)
	frames, _ := FragmentPayload(payload, 7)
	stream := EncodeStream(frames)

	store := cache.New()
	sink := &collectingSink{}
	gw := New(store, sink, nil)

	src := NewStreamSource(bytes.NewReader(stream))
	stored, err := gw.Run(context.Background(), src)
	if err != nil {
		t.Fatalf("run: %v", err)
	}
	if stored != 0 {
		t.Fatalf("forged event must not be stored, stored=%d", stored)
	}
	if store.Len() != 0 {
		t.Fatalf("cache must be empty, len=%d", store.Len())
	}
	if len(sink.frames) != 0 {
		t.Fatalf("forged event must not be rebroadcast, got %d frames", len(sink.frames))
	}
}

func TestGatewayDedupesSameEvent(t *testing.T) {
	priv := mustKey(t)
	ev := sosEvent(t, priv, 1, "same event twice")
	payload, _ := proto.Marshal(ev)

	// Same event under two different msgIds (a rebroadcast on the mesh).
	f1, _ := FragmentPayload(payload, 1)
	f2, _ := FragmentPayload(payload, 2)
	var all [][]byte
	all = append(all, f1...)
	all = append(all, f2...)
	stream := EncodeStream(all)

	store := cache.New()
	gw := New(store, nil, nil)
	src := NewStreamSource(bytes.NewReader(stream))
	stored, err := gw.Run(context.Background(), src)
	if err != nil {
		t.Fatalf("run: %v", err)
	}
	if stored != 1 {
		t.Fatalf("expected 1 stored (deduped), got %d", stored)
	}
}

func TestParseFragmentMalformed(t *testing.T) {
	if _, ok := ParseFragment([]byte{0, 1, 2}); ok {
		t.Fatal("short frame should not parse")
	}
	if _, ok := ParseFragment([]byte{magic, 9, 0, 0, 0, 1, 0}); ok {
		t.Fatal("bad version should not parse")
	}
	// Good single-fragment frame parses.
	frames, _ := FragmentPayload([]byte{1, 2, 3}, 4)
	if _, ok := ParseFragment(frames[0]); !ok {
		t.Fatal("valid frame should parse")
	}
}
