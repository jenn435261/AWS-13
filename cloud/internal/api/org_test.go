package api

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"google.golang.org/protobuf/proto"
)

func pushHelp(t *testing.T, st *store.MemStore, lamport uint64, h3 uint64, cat resiliencev1.ResourceCategory) {
	t.Helper()
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	body, err := proto.Marshal(&resiliencev1.HelpRequestBody{
		RequestId:  "r",
		Categories: []resiliencev1.ResourceCategory{cat},
		Location: &resiliencev1.GeoPoint{
			H3Cell:   h3,
			ExactLat: 37.3354,
			ExactLon: -121.8857,
			HasExact: true,
		},
	})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	ev, err := events.BuildSignedEvent(&resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_HELP_REQUESTED,
		Lamport:       lamport,
		CreatedAtMs:   1_700_000_000_000,
		SchemaVersion: 1,
		H3Cell:        h3,
	}, body, priv)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if _, _, err := st.Push(context.Background(), []*resiliencev1.SignedEvent{ev}); err != nil {
		t.Fatalf("push: %v", err)
	}
}

func TestOrgNeedsRequiresValidToken(t *testing.T) {
	st := store.NewMemStore()
	srv := httptest.NewServer(
		NewServer(st, WithOrgTokens([]string{"secret-token"})).Handler(),
	)
	defer srv.Close()

	// No token -> 401.
	resp, err := http.Get(srv.URL + "/v1/org/needs")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("no token: status = %d, want 401", resp.StatusCode)
	}

	// Wrong token -> 401.
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/org/needs", nil)
	req.Header.Set("X-Org-Token", "wrong")
	resp2, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	resp2.Body.Close()
	if resp2.StatusCode != http.StatusUnauthorized {
		t.Fatalf("wrong token: status = %d, want 401", resp2.StatusCode)
	}
}

func TestOrgNeedsWithValidTokenReturnsAggregateOnly(t *testing.T) {
	st := store.NewMemStore()
	const cell = uint64(0x8928308280fffff)
	pushHelp(t, st, 1, cell, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER)
	pushHelp(t, st, 2, cell, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER)

	srv := httptest.NewServer(
		NewServer(st, WithOrgTokens([]string{"secret-token"})).Handler(),
	)
	defer srv.Close()

	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/org/needs", nil)
	req.Header.Set("X-Org-Token", "secret-token")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("valid token: status = %d, want 200", resp.StatusCode)
	}

	raw, _ := io.ReadAll(resp.Body)

	// Structurally parse the aggregate.
	var report struct {
		Cells []struct {
			H3Cell   uint64 `json:"h3_cell"`
			Category string `json:"category"`
			Count    int    `json:"count"`
		} `json:"cells"`
		GeneratedAt int64 `json:"generated_at"`
		WindowMs    int64 `json:"window_ms"`
	}
	if err := json.Unmarshal(raw, &report); err != nil {
		t.Fatalf("unmarshal report: %v (%s)", err, raw)
	}
	if len(report.Cells) != 1 {
		t.Fatalf("want 1 cell row, got %d (%s)", len(report.Cells), raw)
	}
	if report.Cells[0].Count != 2 || report.Cells[0].H3Cell != cell {
		t.Fatalf("unexpected aggregate: %+v", report.Cells[0])
	}

	// PRIVACY: the raw JSON must not contain any author pubkey hex or exact
	// coordinate value. Assert the exact coords used in pushHelp never appear,
	// and no 64-char hex author key is present.
	body := string(raw)
	for _, forbidden := range []string{"37.3354", "121.8857", "exact", "author", "pubkey", "signature"} {
		if strings.Contains(strings.ToLower(body), forbidden) {
			t.Fatalf("aggregate response leaked %q: %s", forbidden, body)
		}
	}
	// No 64-hex-char author key.
	if containsHexRun(body, 64) {
		t.Fatalf("aggregate response contains a 64-char hex run (possible author key): %s", body)
	}
}

func TestOrgNeedsPostWithCellFilter(t *testing.T) {
	st := store.NewMemStore()
	const cellA = uint64(0x8928308280fffff)
	const cellB = uint64(0x8928308281fffff)
	pushHelp(t, st, 1, cellA, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_WATER)
	pushHelp(t, st, 2, cellB, resiliencev1.ResourceCategory_RESOURCE_CATEGORY_FOOD)

	srv := httptest.NewServer(
		NewServer(st, WithOrgTokens([]string{"tok"})).Handler(),
	)
	defer srv.Close()

	reqBody, _ := json.Marshal(map[string]any{"cells": []uint64{cellA}})
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/org/needs", bytes.NewReader(reqBody))
	req.Header.Set("X-Org-Token", "tok")
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}
	raw, _ := io.ReadAll(resp.Body)
	var report struct {
		Cells []struct {
			H3Cell uint64 `json:"h3_cell"`
		} `json:"cells"`
	}
	if err := json.Unmarshal(raw, &report); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(report.Cells) != 1 || report.Cells[0].H3Cell != cellA {
		t.Fatalf("cell filter not applied: %s", raw)
	}
}

// containsHexRun reports whether s contains a run of n or more consecutive
// lowercase-hex characters (a crude detector for leaked pubkeys/ids).
func containsHexRun(s string, n int) bool {
	run := 0
	for i := 0; i < len(s); i++ {
		c := s[i]
		if (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') {
			run++
			if run >= n {
				return true
			}
		} else {
			run = 0
		}
	}
	return false
}
