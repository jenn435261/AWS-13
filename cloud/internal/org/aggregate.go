// Package org implements the aggregate, consent-respecting organization and
// first-responder integration for the Resilience Network.
//
// THREAT MODEL (non-negotiable): the app must be safe when authorities may be
// HOSTILE while still being useful for legitimate relief. Therefore the org
// integration exposes ONLY aggregated, consented data — "N water requests in
// H3 cell X" — and NEVER individual location tracks, authors, exact
// coordinates, or message contents. There is no mass surveillance and no silent
// tracking here. An individual may separately CHOOSE to reveal their exact
// location to a specific responder via a normal (end-to-end encrypted) location
// share; that path is private to its audience and the cloud treats it as
// opaque.
package org

import (
	"context"
	"sort"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/store"
)

// CellNeed is a single aggregate row: the count of needs for one
// (h3_cell, category) bucket. It deliberately carries NO author, NO exact
// coordinate, and NO message content — only a coarse geospatial bucket, a
// category, and a count.
type CellNeed struct {
	H3Cell   uint64 `json:"h3_cell"`
	Category string `json:"category"`
	Count    int    `json:"count"`
}

// NeedsReport is the aggregate result returned to a verified org. It is the
// ONLY shape of data the org integration ever exposes.
type NeedsReport struct {
	Cells       []CellNeed `json:"cells"`
	GeneratedAt int64      `json:"generated_at"`
	WindowMs    int64      `json:"window_ms"`
}

// Query bounds an aggregation request.
type Query struct {
	// Cells, when non-empty, restricts aggregation to this allow-set of coarse
	// H3 cells. Empty means "all cells".
	Cells []uint64
	// WindowMs, when > 0, restricts aggregation to events whose advisory
	// created_at_ms is within [NowMs-WindowMs, NowMs]. 0 means "all time".
	WindowMs int64
	// NowMs is the reference clock (unix millis) for the freshness window. When
	// 0 it is treated as "no upper bound" and only the lower bound (if any)
	// applies.
	NowMs int64
	// IncludeOffers, when true, also aggregates resource offers/creations into
	// their own category rows so responders can see supply alongside demand.
	// Demand (HELP_REQUESTED) is always aggregated.
	IncludeOffers bool
}

// Aggregator computes aggregate need-by-cell over the authoritative Store.
//
// It reads stored events and collapses them into (h3_cell, category) counts. It
// MUST NOT expose individual authors, exact coordinates, message contents, or
// any location-share payload. In particular LOCATION_SHARE / LOCATION_STOP
// events are SKIPPED entirely: those are private to their audience and the
// cloud never aggregates or exposes them.
type Aggregator struct {
	store store.Store
}

// NewAggregator builds an Aggregator over st.
func NewAggregator(st store.Store) *Aggregator {
	return &Aggregator{store: st}
}

// Needs computes the aggregate NeedsReport for q.
func (a *Aggregator) Needs(ctx context.Context, q Query) (*NeedsReport, error) {
	// Pull every stored event; aggregation is a reduction and must not depend on
	// per-author watermarks.
	evs, err := a.store.PullByAuthorFrom(ctx, nil, 0)
	if err != nil {
		return nil, err
	}

	cellAllow := make(map[uint64]struct{}, len(q.Cells))
	for _, c := range q.Cells {
		cellAllow[c] = struct{}{}
	}
	hasCellFilter := len(cellAllow) > 0

	var lowerMs int64
	if q.WindowMs > 0 && q.NowMs > 0 {
		lowerMs = q.NowMs - q.WindowMs
	}

	// Accumulate counts keyed by (h3_cell, category). We never key by, store, or
	// read the author or any coordinate.
	type key struct {
		h3  uint64
		cat string
	}
	counts := make(map[key]int)

	for _, ev := range evs {
		h := ev.GetHeader()
		if h == nil {
			continue
		}

		// PRIVACY GUARD: never aggregate or expose private location shares.
		switch h.GetType() {
		case resiliencev1.EventType_EVENT_TYPE_LOCATION_SHARE,
			resiliencev1.EventType_EVENT_TYPE_LOCATION_STOP:
			continue
		}

		// Freshness window (advisory created_at_ms).
		if q.WindowMs > 0 {
			ts := h.GetCreatedAtMs()
			if lowerMs > 0 && ts < lowerMs {
				continue
			}
			if q.NowMs > 0 && ts > q.NowMs {
				continue
			}
		}

		cats, cell, ok := a.needRows(ev, q.IncludeOffers)
		if !ok {
			continue
		}
		if hasCellFilter {
			if _, allowed := cellAllow[cell]; !allowed {
				continue
			}
		}
		for _, cat := range cats {
			counts[key{h3: cell, cat: cat}]++
		}
	}

	report := &NeedsReport{
		Cells:       make([]CellNeed, 0, len(counts)),
		GeneratedAt: q.NowMs,
		WindowMs:    q.WindowMs,
	}
	for k, n := range counts {
		report.Cells = append(report.Cells, CellNeed{
			H3Cell:   k.h3,
			Category: k.cat,
			Count:    n,
		})
	}
	// Deterministic ordering for stable responses and tests.
	sort.Slice(report.Cells, func(i, j int) bool {
		if report.Cells[i].H3Cell != report.Cells[j].H3Cell {
			return report.Cells[i].H3Cell < report.Cells[j].H3Cell
		}
		return report.Cells[i].Category < report.Cells[j].Category
	})
	return report, nil
}

// needRows extracts the (categories, coarse cell) contributed by ev, or ok
// false when ev is not an aggregatable need. Only the COARSE h3 bucket is read;
// exact coordinates are never consulted or exposed.
func (a *Aggregator) needRows(ev *resiliencev1.SignedEvent, includeOffers bool) (cats []string, cell uint64, ok bool) {
	switch ev.GetHeader().GetType() {
	case resiliencev1.EventType_EVENT_TYPE_HELP_REQUESTED:
		var body resiliencev1.HelpRequestBody
		if err := unmarshal(ev.GetBody(), &body); err != nil {
			return nil, 0, false
		}
		cell = coarseCell(ev, body.GetLocation())
		cats = categoryNames(body.GetCategories())
		return cats, cell, true

	case resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED:
		if !includeOffers {
			return nil, 0, false
		}
		var body resiliencev1.ResourceBody
		if err := unmarshal(ev.GetBody(), &body); err != nil {
			return nil, 0, false
		}
		cell = coarseCell(ev, body.GetLocation())
		cats = categoryNames([]resiliencev1.ResourceCategory{body.GetCategory()})
		for i := range cats {
			cats[i] = "offer:" + cats[i]
		}
		return cats, cell, true

	default:
		return nil, 0, false
	}
}

// coarseCell returns the coarse H3 bucket for an event: it prefers the body
// location's coarse h3_cell and falls back to the header's coarse bucket. It
// NEVER reads exact coordinates.
func coarseCell(ev *resiliencev1.SignedEvent, loc *resiliencev1.GeoPoint) uint64 {
	if loc != nil && loc.GetH3Cell() != 0 {
		return loc.GetH3Cell()
	}
	return ev.GetHeader().GetH3Cell()
}

// categoryNames maps resource categories to stable string labels. An empty list
// collapses to a single "unspecified" bucket so a need without a declared
// category is still counted once (never dropped silently).
func categoryNames(cats []resiliencev1.ResourceCategory) []string {
	if len(cats) == 0 {
		return []string{categoryLabel(resiliencev1.ResourceCategory_RESOURCE_CATEGORY_UNSPECIFIED)}
	}
	out := make([]string, 0, len(cats))
	seen := make(map[string]struct{}, len(cats))
	for _, c := range cats {
		label := categoryLabel(c)
		if _, dup := seen[label]; dup {
			continue
		}
		seen[label] = struct{}{}
		out = append(out, label)
	}
	return out
}

func categoryLabel(c resiliencev1.ResourceCategory) string {
	if name, ok := resiliencev1.ResourceCategory_name[int32(c)]; ok {
		return name
	}
	return resiliencev1.ResourceCategory_name[int32(resiliencev1.ResourceCategory_RESOURCE_CATEGORY_UNSPECIFIED)]
}
