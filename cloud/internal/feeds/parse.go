package feeds

import (
	"encoding/json"
	"strings"
	"time"
)

// geoJSONGeometry is a minimal GeoJSON geometry decoder covering the types the
// public feeds use (Point, Polygon, MultiPolygon). Coordinates are decoded
// lazily so a mixed document does not fail on an unexpected nesting depth.
type geoJSONGeometry struct {
	Type        string          `json:"type"`
	Coordinates json.RawMessage `json:"coordinates"`
}

// centroidOf returns a representative (lat, lon) for a geometry and true, or
// false when it is nil/empty/unparseable. GeoJSON orders coordinates as
// [lon, lat]. The centroid is the mean of the geometry's vertices, which is a
// stable, non-fabricated point inside or near the affected area (good enough
// for a radius filter; we never invent a point for a geometry-less record).
func centroidOf(g *geoJSONGeometry) (lat, lon float64, ok bool) {
	if g == nil || len(g.Coordinates) == 0 {
		return 0, 0, false
	}
	var sumLat, sumLon float64
	var n int
	switch strings.ToLower(g.Type) {
	case "point":
		var pt []float64
		if err := json.Unmarshal(g.Coordinates, &pt); err != nil || len(pt) < 2 {
			return 0, 0, false
		}
		return pt[1], pt[0], true
	case "polygon":
		var rings [][][]float64
		if err := json.Unmarshal(g.Coordinates, &rings); err != nil {
			return 0, 0, false
		}
		for _, ring := range rings {
			for _, c := range ring {
				if len(c) >= 2 {
					sumLon += c[0]
					sumLat += c[1]
					n++
				}
			}
		}
	case "multipolygon":
		var polys [][][][]float64
		if err := json.Unmarshal(g.Coordinates, &polys); err != nil {
			return 0, 0, false
		}
		for _, poly := range polys {
			for _, ring := range poly {
				for _, c := range ring {
					if len(c) >= 2 {
						sumLon += c[0]
						sumLat += c[1]
						n++
					}
				}
			}
		}
	default:
		return 0, 0, false
	}
	if n == 0 {
		return 0, 0, false
	}
	return sumLat / float64(n), sumLon / float64(n), true
}

// normalizeSeverity maps a free-form upstream severity string to a Severity.
func normalizeSeverity(s string) Severity {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "extreme":
		return SeverityExtreme
	case "severe":
		return SeveritySevere
	case "moderate":
		return SeverityModerate
	case "minor":
		return SeverityMinor
	default:
		return SeverityUnknown
	}
}

// parseISOms parses an RFC3339 / ISO-8601 timestamp into unix millis, or 0 when
// empty or unparseable.
func parseISOms(s string) int64 {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}
	for _, layout := range []string{time.RFC3339, time.RFC3339Nano, "2006-01-02T15:04:05Z07:00"} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UnixMilli()
		}
	}
	return 0
}

// firstNonEmpty returns the first non-blank string, or "" if none.
func firstNonEmpty(ss ...string) string {
	for _, s := range ss {
		if strings.TrimSpace(s) != "" {
			return s
		}
	}
	return ""
}

// nonEmpty returns the non-blank strings in order.
func nonEmpty(ss ...string) []string {
	out := make([]string, 0, len(ss))
	for _, s := range ss {
		if strings.TrimSpace(s) != "" {
			out = append(out, s)
		}
	}
	return out
}
