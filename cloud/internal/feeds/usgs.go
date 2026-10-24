package feeds

import (
	"encoding/json"
	"fmt"
	"strings"
)

// USGS adapts the USGS earthquakes GeoJSON summary feed
// (earthquake.usgs.gov/.../summary/*.geojson). Each feature is a Point with
// [lon, lat, depth]; properties carry mag, place, time (ms) and a stable id.
type USGS struct{}

// NewUSGS returns the USGS earthquake adapter.
func NewUSGS() *USGS { return &USGS{} }

func (*USGS) Source() Source { return SourceUSGS }
func (*USGS) URL() string {
	return "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/significant_day.geojson"
}

type usgsDoc struct {
	Features []struct {
		ID       string `json:"id"`
		Geometry struct {
			Coordinates []float64 `json:"coordinates"`
		} `json:"geometry"`
		Properties struct {
			Mag   float64 `json:"mag"`
			Place string  `json:"place"`
			Time  int64   `json:"time"`
			Title string  `json:"title"`
			Alert string  `json:"alert"` // green/yellow/orange/red PAGER level
		} `json:"properties"`
	} `json:"features"`
}

func (*USGS) Parse(raw []byte) ([]AlertRecord, error) {
	var doc usgsDoc
	if err := json.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("usgs: decode geojson: %w", err)
	}
	out := make([]AlertRecord, 0, len(doc.Features))
	for _, f := range doc.Features {
		id := strings.TrimSpace(f.ID)
		if id == "" || len(f.Geometry.Coordinates) < 2 {
			continue
		}
		lon, lat := f.Geometry.Coordinates[0], f.Geometry.Coordinates[1]
		title := firstNonEmpty(f.Properties.Title, fmt.Sprintf("M%.1f earthquake", f.Properties.Mag))
		out = append(out, AlertRecord{
			Source:    SourceUSGS,
			NativeID:  id,
			Title:     title,
			Detail:    firstNonEmpty(f.Properties.Place, f.Properties.Title),
			Severity:  usgsSeverity(f.Properties.Mag, f.Properties.Alert),
			Lat:       lat,
			Lon:       lon,
			OnsetMs:   f.Properties.Time,
			ExpiresMs: 0, // no upstream expiry; Ingestor applies the default TTL
		})
	}
	return out, nil
}

// usgsSeverity maps PAGER alert color (when present) else magnitude to a
// normalized severity. M>=7 or red/orange => extreme; M>=6 or yellow => severe;
// M>=4.5 => moderate; else minor.
func usgsSeverity(mag float64, pager string) Severity {
	switch strings.ToLower(strings.TrimSpace(pager)) {
	case "red", "orange":
		return SeverityExtreme
	case "yellow":
		return SeveritySevere
	}
	switch {
	case mag >= 7.0:
		return SeverityExtreme
	case mag >= 6.0:
		return SeveritySevere
	case mag >= 4.5:
		return SeverityModerate
	default:
		return SeverityMinor
	}
}
