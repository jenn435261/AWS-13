package org

import (
	"context"
	"crypto/ed25519"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"google.golang.org/protobuf/proto"
)

func mustKey(t *testing.T) ed25519.PrivateKey {
	t.Helper()
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	return priv
}

func helpEvent(t *testing.T, priv ed25519.PrivateKey, lamport uint64, h3 uint64, cats ...resiliencev1.ResourceCategory) *resiliencev1.SignedEvent {
	t.Helper()
	body, err := proto.Marshal(&resiliencev1.HelpRequestBody{
		RequestId:  "req",
		Categories: cats,
		Freeform:   "need help",
		Location: &resiliencev1.GeoPoint{
			H3Cell: h3,
			// Exact coords present on the raw request; the aggregator MUST never
			// read or expose them.
			ExactLat: 37.3354,
			ExactLon: -121.8857,
			HasExact: true,
		},
	})
	if err != nil {
		t.Fatalf("marshal help: %v", err)
	}
	h := &resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_HELP_REQUESTED,
		Lamport:       lamport,
		CreatedAtMs:   1_700_000_000_000 + int64(lamport),
		SchemaVersion: 1,
		H3Cell:        h3,
	}
	ev, err := events.BuildSignedEvent(h, body, priv)
	if err != nil {
		t.Fatalf("build help: %v", err)
	}
	return ev
}

func locationShareEvent(t *testing.T, priv ed25519.PrivateKey, lamport uint64, h3 uint64) *resiliencev1.SignedEvent {
	t.Helper()
	body, err := proto.Marshal(&resiliencev1.LocationShareBody{
		ShareId:        "s1",
		Scope:          "contact:deadbeef",
		H3Cell:         h3,
		EncryptedPoint: []byte{0x01, 0x02, 0x03},
		ExpiresMs:      1_700_000_900_000,
	})
	if err != nil {
		t.Fatalf("marshal share: %v", err)
	}
	h := &resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_LOCATION_SHARE,
		Lamport:       lamport,
		CreatedAtMs:   1_700_000_000_000 + int64(lamport),
		SchemaVersion: 1,
		H3Cell:        h3,
	}
	ev, err := events.BuildSignedEvent(h, body, priv)
	if err != nil {
		t.Fatalf("build share: %v", err)
	}
	return ev
}

func TestAggregatorGroupsByCellAndCategory(t *testing.T) {
	st := store.NewMemStore()
	ctx := context.Background()

	const cellA = uint64(0x8928308280fffff)
	const cellB = uint64(0x8928308281fffff)

	a := mustKey(t)
	b := mustKey(t)
	c := mustKey(t)

	evs := []*resiliencev1.SignedEvent{
		// cellA: 2 water, 1 medicine (across different authors)
		helpEvent(t, a, 1, cellA, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER),
		helpEvent(t, b, 1, cellA, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER),
		helpEvent(t, c, 1, cellA, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_MEDICINE),
		// cellB: 1 water
		helpEvent(t, a, 2, cellB, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER),
		// A private location share in cellA that MUST be ignored entirely.
		locationShareEvent(t, b, 2, cellA),
	}
	if _, rej, err := st.Push(ctx, evs); err != nil || len(rej) != 0 {
		t.Fatalf("push: rej=%d err=%v", len(rej), err)
	}

	agg := NewAggregator(st)
	report, err := agg.Needs(ctx, Query{})
	if err != nil {
		t.Fatalf("needs: %v", err)
	}

	want := map[[2]interface{}]int{
		{cellA, "RESOURCE_CATEGORY_WATER"}:    2,
		{cellA, "RESOURCE_CATEGORY_MEDICINE"}: 1,
		{cellB, "RESOURCE_CATEGORY_WATER"}:    1,
	}
	if len(report.Cells) != len(want) {
		t.Fatalf("got %d cell rows, want %d: %+v", len(report.Cells), len(want), report.Cells)
	}
	for _, row := range report.Cells {
		k := [2]interface{}{row.H3Cell, row.Category}
		if want[k] != row.Count {
			t.Fatalf("row %+v count=%d, want %d", row, row.Count, want[k])
		}
	}

	// PRIVACY: the LOCATION_SHARE contributed nothing. If it had, cellA water
	// would be wrong or a share category would appear.
	for _, row := range report.Cells {
		if row.Category == "" {
			t.Fatalf("empty category leaked")
		}
	}
}

func TestAggregatorExposesNoAuthorsOrCoords(t *testing.T) {
	st := store.NewMemStore()
	ctx := context.Background()
	const cell = uint64(0x8928308280fffff)
	a := mustKey(t)
	if _, _, err := st.Push(ctx, []*resiliencev1.SignedEvent{
		helpEvent(t, a, 1, cell, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_FOOD),
	}); err != nil {
		t.Fatalf("push: %v", err)
	}

	agg := NewAggregator(st)
	report, err := agg.Needs(ctx, Query{})
	if err != nil {
		t.Fatalf("needs: %v", err)
	}

	if len(report.Cells) != 1 {
		t.Fatalf("want 1 row, got %d", len(report.Cells))
	}
	row := report.Cells[0]
	if row.H3Cell != cell {
		t.Fatalf("h3 = %d, want %d", row.H3Cell, cell)
	}
	if row.Count != 1 {
		t.Fatalf("count = %d, want 1", row.Count)
	}
	// There is no field on CellNeed or NeedsReport that could carry an author or
	// a coordinate — the type system enforces the privacy guarantee.
}

func TestAggregatorIgnoresLocationSharesEntirely(t *testing.T) {
	st := store.NewMemStore()
	ctx := context.Background()
	const cell = uint64(0x8928308280fffff)
	a := mustKey(t)

	// Only location shares/stops in the store -> zero aggregate rows.
	if _, _, err := st.Push(ctx, []*resiliencev1.SignedEvent{
		locationShareEvent(t, a, 1, cell),
		locationShareEvent(t, a, 2, cell),
	}); err != nil {
		t.Fatalf("push: %v", err)
	}

	agg := NewAggregator(st)
	report, err := agg.Needs(ctx, Query{})
	if err != nil {
		t.Fatalf("needs: %v", err)
	}
	if len(report.Cells) != 0 {
		t.Fatalf("location shares leaked into aggregate: %+v", report.Cells)
	}
}

func TestAggregatorCellFilter(t *testing.T) {
	st := store.NewMemStore()
	ctx := context.Background()
	const cellA = uint64(0x8928308280fffff)
	const cellB = uint64(0x8928308281fffff)
	a := mustKey(t)
	if _, _, err := st.Push(ctx, []*resiliencev1.SignedEvent{
		helpEvent(t, a, 1, cellA, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER),
		helpEvent(t, a, 2, cellB, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER),
	}); err != nil {
		t.Fatalf("push: %v", err)
	}
	agg := NewAggregator(st)
	report, err := agg.Needs(ctx, Query{Cells: []uint64{cellA}})
	if err != nil {
		t.Fatalf("needs: %v", err)
	}
	if len(report.Cells) != 1 || report.Cells[0].H3Cell != cellA {
		t.Fatalf("cell filter failed: %+v", report.Cells)
	}
}
