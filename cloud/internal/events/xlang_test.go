package events

import (
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"google.golang.org/protobuf/proto"
)

// vectorPath is where the Dart tool (app/tool/gen_vector.dart) writes a
// Dart-signed SignedEvent. The cross-language contract: an event produced by
// the Dart client (BLAKE2b-256 content hash + Ed25519 signature over the
// canonical protobuf preimages) MUST verify in Go, or app<->cloud sync breaks.
const vectorPath = "/projects/sandbox/.toolchain/xlang/vector.json"

type dartVector struct {
	EventB64   string `json:"event_b64"`
	PubB64     string `json:"pub_b64"`
	EventIDHex string `json:"event_id_hex"`
}

func TestVerifiesDartSignedEvent(t *testing.T) {
	raw, err := os.ReadFile(vectorPath)
	if err != nil {
		t.Skipf("no cross-language vector present (%v); run app/tool/gen_vector.dart to produce it", err)
	}
	var v dartVector
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatalf("bad vector json: %v", err)
	}

	evBytes, err := base64.StdEncoding.DecodeString(v.EventB64)
	if err != nil {
		t.Fatalf("decode event_b64: %v", err)
	}

	ev := &resiliencev1.SignedEvent{}
	if err := proto.Unmarshal(evBytes, ev); err != nil {
		t.Fatalf("unmarshal SignedEvent: %v", err)
	}

	// 1. Go recomputes the same content hash as Dart.
	gotID, err := ComputeEventID(ev.Header, ev.Body)
	if err != nil {
		t.Fatalf("ComputeEventID: %v", err)
	}
	if hex.EncodeToString(gotID) != v.EventIDHex {
		t.Fatalf("content-hash mismatch:\n  go  =%s\n  dart=%s", hex.EncodeToString(gotID), v.EventIDHex)
	}
	if hex.EncodeToString(ev.Header.EventId) != v.EventIDHex {
		t.Fatalf("stored event_id != dart event_id")
	}

	// 2. Go accepts the Dart Ed25519 signature over the canonical preimage.
	ok, reason := VerifyEvent(ev)
	if !ok {
		t.Fatalf("Go rejected a Dart-signed event: %s", reason)
	}

	// 3. Tampering is still caught across the boundary.
	tampered := proto.Clone(ev).(*resiliencev1.SignedEvent)
	tampered.Body[0] ^= 0xFF
	if ok, _ := VerifyEvent(tampered); ok {
		t.Fatalf("Go accepted a tampered Dart event")
	}
}
