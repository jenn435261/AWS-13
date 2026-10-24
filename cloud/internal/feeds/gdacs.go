package feeds

import (
	"encoding/json"
	"fmt"
	"strings"
)

// GDACS adapts the Global Disaster Alert and Coordination System GeoJSON feed
// (gdacs.org/gdacsapi/.../SEARCH/geteventlist/MAP). Each feature is a Point with
// properties carrying the event id/type, name, alert level (Green/Orange/Red)
// and dates.
type GDACS struct{}

// NewGDACS returns the GDACS adapter.
func NewGDACS() *GDACS { return &GDACS{} }

func (*GDACS) Source() Source { return SourceGDACS }
func (*GDACS) URL() string {
	return "https://www.gdacs.org/gdacsapi/api/events/geteventlist/MAP"
}

type gdacsDoc struct {
	Features []struct {
		Geometry struct {
			Coordinates []float64 `json:"coordinates"`
		} `json:"geometry"`
		Properties struct {
			EventID    json.RawMessage `json:"eventid"`
			EventType  string          `json:"eventtype"`
			EventName  string          `json:"eventname"`
			Name       string          `json:"name"`
			AlertLevel string          `json:"alertlevel"`
			FromDate   string          `json:"fromdate"`
			ToDate     string          `json:"todate"`
			HTMLDesc   string          `json:"htmldescription"`
		} `json:"properties"`
	} `json:"features"`
}

func (*GDACS) Parse(raw []byte) ([]AlertRecord, error) {
	var doc gdacsDoc
	if err := json.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("gdacs: decode geojson: %w", err)
	}
	out := make([]AlertRecord, 0, len(doc.Features))
	for _, f := range doc.Features {
		p := f.Properties
		eid := rawToString(p.EventID)
		etype := strings.TrimSpace(p.EventType)
		if eid == "" || etype == "" || len(f.Geometry.Coordinates) < 2 {
			continue
		}
		id := fmt.Sprintf("%s-%s", etype, eid)
		lon, lat := f.Geometry.Coordinates[0], f.Geometry.Coordinates[1]
		title := firstNonEmpty(p.EventName, p.Name, gdacsTypeLabel(etype))
		out = append(out, AlertRecord{
			Source:    SourceGDACS,
			NativeID:  id,
			Title:     title,
			Detail:    firstNonEmpty(stripHTML(p.HTMLDesc), p.Name),
			Severity:  gdacsSeverity(p.AlertLevel),
			Lat:       lat,
			Lon:       lon,
			OnsetMs:   parseISOms(p.FromDate),
			ExpiresMs: parseISOms(p.ToDate),
		})
	}
	return out, nil
}

func gdacsTypeLabel(t string) string {
	switch strings.ToUpper(t) {
	case "EQ":
		return "Earthquake"
	case "TC":
		return "Tropical cyclone"
	case "FL":
		return "Flood"
	case "VO":
		return "Volcano"
	case "DR":
		return "Drought"
	case "WF":
		return "Wildfire"
	default:
		return "Disaster event"
	}
}

func gdacsSeverity(level string) Severity {
	switch strings.ToLower(strings.TrimSpace(level)) {
	case "red":
		return SeverityExtreme
	case "orange":
		return SeveritySevere
	case "green":
		return SeverityMinor
	default:
		return SeverityModerate
	}
}

// rawToString normalizes a JSON value that may be a number (1001234) or a
// string ("1001234" or "") into a trimmed string. An empty/null value yields "".
func rawToString(raw json.RawMessage) string {
	s := strings.TrimSpace(string(raw))
	if s == "" || s == "null" {
		return ""
	}
	// Unquote if it is a JSON string.
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		var str string
		if err := json.Unmarshal(raw, &str); err == nil {
			return strings.TrimSpace(str)
		}
	}
	return s
}

// stripHTML removes the simple tags GDACS embeds in htmldescription so the
// detail is plain text. It is intentionally minimal (not a full parser).
func stripHTML(s string) string {
	var sb strings.Builder
	inTag := false
	for _, r := range s {
		switch {
		case r == '<':
			inTag = true
		case r == '>':
			inTag = false
		case !inTag:
			sb.WriteRune(r)
		}
	}
	return strings.TrimSpace(sb.String())
}
