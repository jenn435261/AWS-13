package api

import (
	"net/http"
	"sort"
	"strings"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/feeds"
	"google.golang.org/protobuf/proto"
)

// safePlaceJSON is one ranked safe place. Every field is derived from a stored,
// verified event or a feed record — a place is NEVER fabricated. source names
// its origin and provenance; age_ms lets the client freshness-decay it.
type safePlaceJSON struct {
	Kind       string  `json:"kind"`       // shelter | supplies | hospital | high_ground
	Title      string  `json:"title"`
	Detail     string  `json:"detail"`
	Lat        float64 `json:"lat"`
	Lon        float64 `json:"lon"`
	DistKm     float64 `json:"distance_km"`
	Source     string  `json:"source"`     // community | verified_org | official_feed:<feed>
	Verified   bool    `json:"verified"`   // backed by a verified-org provenance
	CreatedMs  int64   `json:"created_ms"`
	AgeMs      int64   `json:"age_ms"`
	EventIDHex string  `json:"event_id"`   // the backing event (proves non-fabrication)
}

type safePlacesResponse struct {
	Places   []safePlaceJSON `json:"places"`
	Summary  string          `json:"summary"`
	Degraded bool            `json:"degraded"` // true => AI summary is the rules fallback
	NowMs    int64           `json:"now_ms"`
}

// handleSafePlaces implements GET /v1/safe-places?lat=&lon=&hazard= returning
// ranked shelters/supplies/hospitals/high-ground that combine verified supply
// providers in the store, open shelters from the feeds, plus a plain-language
// AI summary (Bedrock when configured, the deterministic rules fallback
// otherwise, flagged degraded). Every result cites its source + age and is
// backed by a real event — nothing is fabricated.
func (s *Server) handleSafePlaces(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	now := nowMs()
	resp := safePlacesResponse{Places: []safePlaceJSON{}, NowMs: now}

	q := r.URL.Query()
	lat, hasLat := parseFloat(q.Get("lat"))
	lon, hasLon := parseFloat(q.Get("lon"))
	hazard := strings.ToLower(strings.TrimSpace(q.Get("hazard")))
	hasGeo := hasLat && hasLon

	evs, err := s.store.PullByAuthorFrom(r.Context(), nil, 0)
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "store pull: "+err.Error())
		return
	}

	// Build the verified-org author set so a place can be tagged verified.
	verifiedAuthors := s.verifiedAuthorSet(evs)

	for _, ev := range evs {
		place, ok := s.placeFromEvent(ev, verifiedAuthors, now)
		if !ok {
			continue
		}
		if hasGeo {
			place.DistKm = round1(haversineKm(lat, lon, place.Lat, place.Lon))
		}
		resp.Places = append(resp.Places, place)
	}

	// Rank: verified first, then (when geo) nearest, then freshest.
	sort.SliceStable(resp.Places, func(i, j int) bool {
		a, b := resp.Places[i], resp.Places[j]
		if a.Verified != b.Verified {
			return a.Verified
		}
		if hasGeo && a.DistKm != b.DistKm {
			return a.DistKm < b.DistKm
		}
		return a.CreatedMs > b.CreatedMs
	})

	// Build the AI summary from the ranked titles. Try the online assistant,
	// fall back to deterministic rules, and ALWAYS flag degraded honestly.
	items := summaryItems(hazard, resp.Places)
	degraded := true
	var summary string
	if s.online != nil && len(items) > 0 {
		if out, serr := s.online.Summarize(r.Context(), items); serr == nil {
			summary, degraded = out, false
		}
	}
	if degraded {
		summary, _ = s.rules.Summarize(r.Context(), items)
	}
	resp.Summary = summary
	resp.Degraded = degraded

	s.writeAIJSON(w, resp)
}

// placeFromEvent maps a stored event to a safe place when it is a shelter, a
// supply/hospital resource, or an official-feed shelter alert. It returns
// (_, false) for every other event type. A place always carries the backing
// event id, which is the proof it is not fabricated.
func (s *Server) placeFromEvent(ev *resiliencev1.SignedEvent, verified map[string]bool, now int64) (safePlaceJSON, bool) {
	hdr := ev.GetHeader()
	author := authorKeyHex(hdr.GetAuthorPubkey())
	isVerified := verified[author]
	created := hdr.GetCreatedAtMs()
	eid := hexLower(hdr.GetEventId())

	switch hdr.GetType() {
	case resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED:
		var body resiliencev1.ResourceBody
		if proto.Unmarshal(ev.GetBody(), &body) != nil {
			return safePlaceJSON{}, false
		}
		loc := body.GetLocation()
		if loc == nil {
			return safePlaceJSON{}, false
		}
		kind := "supplies"
		switch {
		case body.GetIsShelter():
			kind = "shelter"
		case body.GetCategory() == resiliencev1.ResourceCategory_RESOURCE_CATEGORY_MEDICAL_HELP:
			kind = "hospital"
		}
		return safePlaceJSON{
			Kind:       kind,
			Title:      firstNonEmptyStr(body.GetTitle(), kind),
			Detail:     body.GetNotes(),
			Lat:        loc.GetApproxLat(),
			Lon:        loc.GetApproxLon(),
			Source:     provenanceLabel(body.GetProvenance(), isVerified),
			Verified:   isVerified || body.GetProvenance() == resiliencev1.ProvenanceKind_PROVENANCE_KIND_VERIFIED_ORG,
			CreatedMs:  created,
			AgeMs:      maxInt64(0, now-created),
			EventIDHex: eid,
		}, true

	case resiliencev1.EventType_EVENT_TYPE_SHELTER_CREATED:
		// A shelter resource body is reused for SHELTER_CREATED in this schema.
		var body resiliencev1.ResourceBody
		if proto.Unmarshal(ev.GetBody(), &body) != nil || body.GetLocation() == nil {
			return safePlaceJSON{}, false
		}
		loc := body.GetLocation()
		return safePlaceJSON{
			Kind:       "shelter",
			Title:      firstNonEmptyStr(body.GetTitle(), "Shelter"),
			Detail:     body.GetNotes(),
			Lat:        loc.GetApproxLat(),
			Lon:        loc.GetApproxLon(),
			Source:     provenanceLabel(body.GetProvenance(), isVerified),
			Verified:   isVerified,
			CreatedMs:  created,
			AgeMs:      maxInt64(0, now-created),
			EventIDHex: eid,
		}, true

	case resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT:
		// An official-feed alert surfaces as an "open shelter" safe place only
		// when its title/detail indicates a shelter or evacuation center. We do
		// NOT invent coordinates: the feed alert carries its own area point.
		var body resiliencev1.EmergencyAlertBody
		if proto.Unmarshal(ev.GetBody(), &body) != nil {
			return safePlaceJSON{}, false
		}
		src, isFeed := feeds.SourceOf(body.GetDetail())
		if !isFeed {
			return safePlaceJSON{}, false
		}
		text := strings.ToLower(body.GetTitle() + " " + body.GetDetail())
		if !strings.Contains(text, "shelter") && !strings.Contains(text, "evacuation") {
			return safePlaceJSON{}, false
		}
		area := body.GetArea()
		if area == nil {
			return safePlaceJSON{}, false
		}
		return safePlaceJSON{
			Kind:       "shelter",
			Title:      firstNonEmptyStr(body.GetTitle(), "Open shelter"),
			Detail:     body.GetDetail(),
			Lat:        area.GetApproxLat(),
			Lon:        area.GetApproxLon(),
			Source:     "official_feed:" + string(src),
			Verified:   true, // feed key is a trusted root
			CreatedMs:  created,
			AgeMs:      maxInt64(0, now-created),
			EventIDHex: eid,
		}, true
	}
	return safePlaceJSON{}, false
}

// verifiedAuthorSet returns the set of author hex keys that have a verified-org
// provenance, derived from the trusted-org key set when configured. Absent a
// trusted-org config every author is treated as community (not verified), so a
// place is never falsely labelled verified.
func (s *Server) verifiedAuthorSet(evs []*resiliencev1.SignedEvent) map[string]bool {
	out := map[string]bool{}
	if s.trustedOrgs == nil {
		return out
	}
	for _, ev := range evs {
		pub := ev.GetHeader().GetAuthorPubkey()
		if s.trustedOrgs.IsVerifiedOrgKey(pub) {
			out[authorKeyHex(pub)] = true
		}
	}
	return out
}

func provenanceLabel(p resiliencev1.ProvenanceKind, verified bool) string {
	if verified || p == resiliencev1.ProvenanceKind_PROVENANCE_KIND_VERIFIED_ORG {
		return "verified_org"
	}
	return "community"
}

// summaryItems turns the ranked places (and hazard) into the short input list
// the summarizer condenses into a plain-language recommendation.
func summaryItems(hazard string, places []safePlaceJSON) []string {
	items := make([]string, 0, len(places)+1)
	if hazard != "" {
		items = append(items, "Hazard: "+hazard)
	}
	for _, p := range places {
		label := p.Title
		if p.DistKm > 0 {
			label += " (" + kmLabel(p.DistKm) + ")"
		}
		if p.Verified {
			label += " [verified]"
		}
		items = append(items, p.Kind+": "+label)
	}
	return items
}

func kmLabel(km float64) string {
	// Simple fixed-point km label; avoids importing strconv formatting here.
	whole := int64(km)
	frac := int64((km - float64(whole)) * 10)
	return itoaLocal(whole) + "." + itoaLocal(frac) + " km"
}

func itoaLocal(n int64) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		b[i] = '-'
	}
	return string(b[i:])
}

func firstNonEmptyStr(a, b string) string {
	if strings.TrimSpace(a) != "" {
		return a
	}
	return b
}

func authorKeyHex(pub []byte) string { return hexLower(pub) }
