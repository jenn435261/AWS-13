package feeds

import (
	"encoding/json"
	"fmt"
	"strings"
)

// NWS adapts the National Weather Service / NOAA active-alerts CAP feed served
// as GeoJSON at api.weather.gov/alerts/active. Each feature carries a CAP alert
// in its properties (event, headline, description, instruction, severity,
// onset/expires) and an optional geometry; we take the geometry centroid as the
// representative point, falling back to the affected-zone centroid when absent.
type NWS struct{}

// NewNWS returns the NWS/NOAA CAP adapter.
func NewNWS() *NWS { return &NWS{} }

func (*NWS) Source() Source { return SourceNWS }
func (*NWS) URL() string    { return "https://api.weather.gov/alerts/active" }

type nwsDoc struct {
	Features []struct {
		Geometry *geoJSONGeometry `json:"geometry"`
		Properties struct {
			ID          string `json:"id"`
			Event       string `json:"event"`
			Headline    string `json:"headline"`
			Description string `json:"description"`
			Instruction string `json:"instruction"`
			Severity    string `json:"severity"`
			Onset       string `json:"onset"`
			Expires     string `json:"expires"`
		} `json:"properties"`
	} `json:"features"`
}

func (*NWS) Parse(raw []byte) ([]AlertRecord, error) {
	var doc nwsDoc
	if err := json.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("nws: decode geojson: %w", err)
	}
	out := make([]AlertRecord, 0, len(doc.Features))
	for _, f := range doc.Features {
		p := f.Properties
		id := strings.TrimSpace(p.ID)
		if id == "" {
			continue // no stable id => skip rather than fabricate
		}
		lat, lon, ok := centroidOf(f.Geometry)
		if !ok {
			// No geometry: still record the alert at (0,0) is unacceptable; a
			// radius filter would place it off California. Skip location-less
			// alerts so /v1/alerts never returns a fabricated point.
			continue
		}
		title := firstNonEmpty(p.Event, p.Headline, "Weather alert")
		detail := strings.TrimSpace(strings.Join(nonEmpty(p.Headline, p.Description, p.Instruction), "\n\n"))
		out = append(out, AlertRecord{
			Source:    SourceNWS,
			NativeID:  id,
			Title:     title,
			Detail:    detail,
			Severity:  normalizeSeverity(p.Severity),
			Lat:       lat,
			Lon:       lon,
			OnsetMs:   parseISOms(p.Onset),
			ExpiresMs: parseISOms(p.Expires),
		})
	}
	return out, nil
}
