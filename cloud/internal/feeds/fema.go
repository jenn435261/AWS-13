package feeds

import (
	"encoding/json"
	"fmt"
	"strings"
)

// FEMA adapts the OpenFEMA DisasterDeclarationsSummaries endpoint
// (www.fema.gov/api/open/v2/DisasterDeclarationsSummaries). Records are JSON
// (not GeoJSON): a declaration carries a state, declaration type, incident
// type, title and dates, but NOT a precise lat/lon. We resolve a representative
// point from a built-in US state-centroid table; a declaration whose state is
// unknown is skipped (no fabricated point).
type FEMA struct{}

// NewFEMA returns the FEMA OpenFEMA adapter.
func NewFEMA() *FEMA { return &FEMA{} }

func (*FEMA) Source() Source { return SourceFEMA }
func (*FEMA) URL() string {
	return "https://www.fema.gov/api/open/v2/DisasterDeclarationsSummaries?$orderby=declarationDate%20desc&$top=200"
}

type femaDoc struct {
	Summaries []struct {
		DisasterNumber   int    `json:"disasterNumber"`
		FemaDeclarationID string `json:"femaDeclarationString"`
		State            string `json:"state"`
		DeclarationType  string `json:"declarationType"`
		DeclarationTitle string `json:"declarationTitle"`
		IncidentType     string `json:"incidentType"`
		IncidentBeginMs  string `json:"incidentBeginDate"`
		IncidentEndMs    string `json:"incidentEndDate"`
	} `json:"DisasterDeclarationsSummaries"`
}

func (*FEMA) Parse(raw []byte) ([]AlertRecord, error) {
	var doc femaDoc
	if err := json.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("fema: decode json: %w", err)
	}
	out := make([]AlertRecord, 0, len(doc.Summaries))
	for _, s := range doc.Summaries {
		id := firstNonEmpty(s.FemaDeclarationID, fmt.Sprintf("DR-%d-%s", s.DisasterNumber, s.State))
		lat, lon, ok := stateCentroid(s.State)
		if !ok {
			continue // unknown state => no point => skip (never fabricate)
		}
		title := firstNonEmpty(s.DeclarationTitle, s.IncidentType, "FEMA disaster declaration")
		detail := strings.TrimSpace(strings.Join(nonEmpty(
			s.IncidentType,
			femaTypeLabel(s.DeclarationType),
			"State: "+s.State,
		), " · "))
		out = append(out, AlertRecord{
			Source:    SourceFEMA,
			NativeID:  id,
			Title:     title,
			Detail:    detail,
			Severity:  femaSeverity(s.DeclarationType),
			Lat:       lat,
			Lon:       lon,
			OnsetMs:   parseISOms(s.IncidentBeginMs),
			ExpiresMs: parseISOms(s.IncidentEndMs),
		})
	}
	return out, nil
}

func femaTypeLabel(t string) string {
	switch strings.ToUpper(strings.TrimSpace(t)) {
	case "DR":
		return "Major disaster declaration"
	case "EM":
		return "Emergency declaration"
	case "FM":
		return "Fire management assistance"
	default:
		return ""
	}
}

// femaSeverity: a major disaster (DR) is severe; an emergency (EM) moderate;
// anything else minor.
func femaSeverity(t string) Severity {
	switch strings.ToUpper(strings.TrimSpace(t)) {
	case "DR":
		return SeveritySevere
	case "EM":
		return SeverityModerate
	default:
		return SeverityMinor
	}
}

// stateCentroid returns an approximate geographic centroid (lat, lon) for a US
// state/territory postal code, or false when unknown. These are coarse but
// real reference points; a radius filter uses them to place a state-level FEMA
// declaration. We NEVER return (0,0) for an unknown code.
func stateCentroid(code string) (lat, lon float64, ok bool) {
	c, found := stateCentroids[strings.ToUpper(strings.TrimSpace(code))]
	if !found {
		return 0, 0, false
	}
	return c[0], c[1], true
}

var stateCentroids = map[string][2]float64{
	"AL": {32.806, -86.791}, "AK": {61.370, -152.404}, "AZ": {33.729, -111.431},
	"AR": {34.969, -92.373}, "CA": {36.116, -119.682}, "CO": {39.059, -105.311},
	"CT": {41.597, -72.755}, "DE": {39.318, -75.507}, "FL": {27.766, -81.686},
	"GA": {33.040, -83.643}, "HI": {21.094, -157.498}, "ID": {44.240, -114.478},
	"IL": {40.349, -88.986}, "IN": {39.849, -86.258}, "IA": {42.011, -93.210},
	"KS": {38.526, -96.726}, "KY": {37.668, -84.670}, "LA": {31.169, -91.867},
	"ME": {44.693, -69.381}, "MD": {39.064, -76.802}, "MA": {42.230, -71.530},
	"MI": {43.326, -84.536}, "MN": {45.694, -93.900}, "MS": {32.741, -89.678},
	"MO": {38.456, -92.288}, "MT": {46.921, -110.454}, "NE": {41.125, -98.268},
	"NV": {38.313, -117.055}, "NH": {43.452, -71.564}, "NJ": {40.298, -74.521},
	"NM": {34.840, -106.248}, "NY": {42.166, -74.948}, "NC": {35.630, -79.806},
	"ND": {47.528, -99.784}, "OH": {40.388, -82.764}, "OK": {35.565, -96.928},
	"OR": {44.572, -122.071}, "PA": {40.590, -77.209}, "RI": {41.680, -71.511},
	"SC": {33.856, -80.945}, "SD": {44.299, -99.438}, "TN": {35.747, -86.692},
	"TX": {31.054, -97.563}, "UT": {40.150, -111.862}, "VT": {44.045, -72.710},
	"VA": {37.769, -78.170}, "WA": {47.400, -121.490}, "WV": {38.491, -80.954},
	"WI": {44.268, -89.616}, "WY": {42.756, -107.302}, "DC": {38.898, -77.026},
	"PR": {18.220, -66.590}, "GU": {13.444, 144.794}, "VI": {18.336, -64.896},
	"AS": {-14.271, -170.132}, "MP": {15.097, 145.674},
}
