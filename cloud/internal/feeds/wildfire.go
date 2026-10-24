package feeds

import (
	"encoding/json"
	"fmt"
	"strings"
)

// Wildfire adapts the NIFC (National Interagency Fire Center) current-incidents
// GeoJSON feed (an ArcGIS FeatureServer layer). Each feature is a Point with
// incident attributes (name, acres, containment, discovery time). It is a stand
// in for the FIRMS active-fire feed too: both are point features with a stable
// id and a lon/lat, so the same adapter shape handles either; NIFC is chosen as
// the default because it carries human-readable incident metadata.
type Wildfire struct{}

// NewWildfire returns the wildfire adapter.
func NewWildfire() *Wildfire { return &Wildfire{} }

func (*Wildfire) Source() Source { return SourceWildfire }
func (*Wildfire) URL() string {
	return "https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/Current_WildlandFire_Locations/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson"
}

type wildfireDoc struct {
	Features []struct {
		Geometry struct {
			Coordinates []float64 `json:"coordinates"`
		} `json:"geometry"`
		Properties struct {
			IrwinID          string  `json:"IrwinID"`
			UniqueFireID     string  `json:"UniqueFireIdentifier"`
			IncidentName     string  `json:"IncidentName"`
			FireDiscoveryMs  int64   `json:"FireDiscoveryDateTime"` // epoch ms in NIFC
			DailyAcres       float64 `json:"DailyAcres"`
			PercentContained float64 `json:"PercentContained"`
		} `json:"properties"`
	} `json:"features"`
}

func (*Wildfire) Parse(raw []byte) ([]AlertRecord, error) {
	var doc wildfireDoc
	if err := json.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("wildfire: decode geojson: %w", err)
	}
	out := make([]AlertRecord, 0, len(doc.Features))
	for _, f := range doc.Features {
		p := f.Properties
		id := firstNonEmpty(p.IrwinID, p.UniqueFireID)
		if id == "" || len(f.Geometry.Coordinates) < 2 {
			continue
		}
		lon, lat := f.Geometry.Coordinates[0], f.Geometry.Coordinates[1]
		name := firstNonEmpty(p.IncidentName, "Wildfire incident")
		var sb strings.Builder
		if p.DailyAcres > 0 {
			fmt.Fprintf(&sb, "%.0f acres. ", p.DailyAcres)
		}
		fmt.Fprintf(&sb, "%.0f%% contained.", p.PercentContained)
		out = append(out, AlertRecord{
			Source:    SourceWildfire,
			NativeID:  id,
			Title:     name + " (wildfire)",
			Detail:    strings.TrimSpace(sb.String()),
			Severity:  wildfireSeverity(p.DailyAcres, p.PercentContained),
			Lat:       lat,
			Lon:       lon,
			OnsetMs:   p.FireDiscoveryMs,
			ExpiresMs: 0,
		})
	}
	return out, nil
}

// wildfireSeverity: large and poorly-contained fires are more severe. A fire
// over 10k acres under 25% contained is extreme; over 1k acres severe; else
// moderate.
func wildfireSeverity(acres, contained float64) Severity {
	switch {
	case acres >= 10000 && contained < 25:
		return SeverityExtreme
	case acres >= 1000:
		return SeveritySevere
	case acres > 0:
		return SeverityModerate
	default:
		return SeverityMinor
	}
}
