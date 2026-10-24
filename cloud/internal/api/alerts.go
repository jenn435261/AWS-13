package api

import (
	"math"
	"net/http"
	"sort"
	"strconv"
	"time"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/feeds"
	"github.com/resilience-network/aws13/cloud/internal/store"
	"google.golang.org/protobuf/proto"
)

// nowMs returns the current wall-clock time in unix milliseconds.
func nowMs() int64 { return time.Now().UnixMilli() }

// alertJSON is one official-feed alert in the /v1/alerts response. It carries
// source + age so a client can label and freshness-decay it honestly; it is
// derived ONLY from a stored, verified EMERGENCY_ALERT event (never fabricated).
type alertJSON struct {
	AlertID   string  `json:"alert_id"`
	Title     string  `json:"title"`
	Detail    string  `json:"detail"`
	Priority  string  `json:"priority"`
	Source    string  `json:"source"` // e.g. "official_feed:nws"
	Lat       float64 `json:"lat"`
	Lon       float64 `json:"lon"`
	DistKm    float64 `json:"distance_km"`
	CreatedMs int64   `json:"created_ms"`
	ExpiresMs int64   `json:"expires_ms"`
	AgeMs     int64   `json:"age_ms"`
}

type alertsResponse struct {
	Alerts     []alertJSON `json:"alerts"`
	NowMs      int64       `json:"now_ms"`
	FeedPubkey string      `json:"feed_pubkey"` // trusted root clients verify against
}

// handleAlerts implements GET /v1/alerts?lat=&lon=&radius_km=&since= returning
// the cloud official-feed EMERGENCY_ALERT events, filtered by radius (when
// lat/lon/radius_km are given) and by since (created_at_ms, when given). The
// same events also appear in /v1/events/pull (they are ordinary stored events),
// so existing sync picks them up; this endpoint is a convenience view scoped to
// feed alerts with geo/freshness filtering and source+age metadata.
func (s *Server) handleAlerts(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		s.writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	resp := alertsResponse{Alerts: []alertJSON{}, NowMs: nowMs()}
	if len(s.feedPubkey) == ed25519PubLen {
		resp.FeedPubkey = hexLower(s.feedPubkey)
	} else {
		// No feed configured: honest empty set (never fabricate alerts).
		s.writeAIJSON(w, resp)
		return
	}

	q := r.URL.Query()
	lat, hasLat := parseFloat(q.Get("lat"))
	lon, hasLon := parseFloat(q.Get("lon"))
	radiusKm, _ := parseFloat(q.Get("radius_km"))
	since, _ := strconv.ParseInt(q.Get("since"), 10, 64)
	hasGeo := hasLat && hasLon && radiusKm > 0

	// Pull only the feed author's events from the store (verify-before-store
	// already ran when they were ingested).
	from := map[string]uint64{store.AuthorKey(s.feedPubkey): 0}
	evs, err := s.store.PullByAuthorFrom(r.Context(), from, 0)
	if err != nil {
		s.writeError(w, http.StatusInternalServerError, "store pull: "+err.Error())
		return
	}

	for _, ev := range evs {
		if ev.GetHeader().GetType() != resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT {
			continue
		}
		var body resiliencev1.EmergencyAlertBody
		if uerr := proto.Unmarshal(ev.GetBody(), &body); uerr != nil {
			continue
		}
		src, isFeed := feeds.SourceOf(body.GetDetail())
		if !isFeed {
			continue // only official-feed alerts here
		}
		created := ev.GetHeader().GetCreatedAtMs()
		if since > 0 && created <= since {
			continue
		}
		// Drop expired alerts (never surface something no longer valid).
		if exp := body.GetExpiresMs(); exp > 0 && exp <= resp.NowMs {
			continue
		}
		aLat := body.GetArea().GetApproxLat()
		aLon := body.GetArea().GetApproxLon()
		dist := 0.0
		if hasGeo {
			dist = haversineKm(lat, lon, aLat, aLon)
			if dist > radiusKm {
				continue
			}
		}
		resp.Alerts = append(resp.Alerts, alertJSON{
			AlertID:   body.GetAlertId(),
			Title:     body.GetTitle(),
			Detail:    body.GetDetail(),
			Priority:  body.GetPriority().String(),
			Source:    "official_feed:" + string(src),
			Lat:       aLat,
			Lon:       aLon,
			DistKm:    round1(dist),
			CreatedMs: created,
			ExpiresMs: body.GetExpiresMs(),
			AgeMs:     maxInt64(0, resp.NowMs-created),
		})
	}

	// Rank: by distance when geo-filtered, else newest first.
	sort.SliceStable(resp.Alerts, func(i, j int) bool {
		if hasGeo && resp.Alerts[i].DistKm != resp.Alerts[j].DistKm {
			return resp.Alerts[i].DistKm < resp.Alerts[j].DistKm
		}
		return resp.Alerts[i].CreatedMs > resp.Alerts[j].CreatedMs
	})

	s.writeAIJSON(w, resp)
}

const ed25519PubLen = 32

func parseFloat(s string) (float64, bool) {
	if s == "" {
		return 0, false
	}
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0, false
	}
	return v, true
}

// haversineKm returns the great-circle distance in kilometers between two
// WGS84 points.
func haversineKm(lat1, lon1, lat2, lon2 float64) float64 {
	const earthKm = 6371.0088
	rlat1 := lat1 * math.Pi / 180
	rlat2 := lat2 * math.Pi / 180
	dlat := (lat2 - lat1) * math.Pi / 180
	dlon := (lon2 - lon1) * math.Pi / 180
	a := math.Sin(dlat/2)*math.Sin(dlat/2) +
		math.Cos(rlat1)*math.Cos(rlat2)*math.Sin(dlon/2)*math.Sin(dlon/2)
	return earthKm * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

func round1(v float64) float64 { return math.Round(v*10) / 10 }

func maxInt64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}

const hexDigits = "0123456789abcdef"

func hexLower(b []byte) string {
	out := make([]byte, len(b)*2)
	for i, c := range b {
		out[i*2] = hexDigits[c>>4]
		out[i*2+1] = hexDigits[c&0x0f]
	}
	return string(out)
}
