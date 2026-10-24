// Package feeds ingests public emergency/hazard feeds (NWS/NOAA CAP, USGS
// earthquakes, NIFC/FIRMS wildfire, FEMA OpenFEMA, GDACS) and maps each source
// record into a signed EVENT_TYPE_EMERGENCY_ALERT event marked
// source=official_feed.
//
// Design:
//
//   - A pluggable [Feed] interface. Each concrete adapter parses the bytes it
//     receives from its upstream (or a canned test fixture) into a slice of
//     [AlertRecord]. Parsing NEVER performs network I/O itself: the caller hands
//     it the raw bytes. This is what makes the adapters deterministically
//     testable from checked-in fixtures with no live network (see the
//     *_test.go files and testdata/).
//
//   - An [Ingestor] signs each [AlertRecord] into a cloud-signed SignedEvent
//     using the cloud-service "feed key". The feed key is a single Ed25519
//     identity the clients trust as a root so feed alerts render as Official
//     (verified), not community.
//
//   - source=official_feed is carried WITHOUT a proto change (see DECISIONS):
//     the alert_id is namespaced "feed:<source>:<native-id>" and the detail
//     string is prefixed with a canonical marker line that [SourceOf]/[IsFeed]
//     parse back out. This keeps EmergencyAlertBody unchanged while every feed
//     alert is self-describing and stably de-duplicated by content hash across
//     ingest runs.
package feeds

import (
	"crypto/ed25519"
	"fmt"
	"sort"
	"strings"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"google.golang.org/protobuf/proto"
)

// Source names a public feed. It is the stable machine identifier carried in
// the alert id and the detail marker.
type Source string

const (
	SourceNWS      Source = "nws"      // NWS/NOAA CAP (api.weather.gov/alerts/active)
	SourceUSGS     Source = "usgs"     // USGS earthquakes GeoJSON
	SourceWildfire Source = "wildfire" // NIFC/FIRMS wildfire
	SourceFEMA     Source = "fema"     // FEMA OpenFEMA disaster declarations
	SourceGDACS    Source = "gdacs"    // GDACS global disaster alerts
)

// marker is the canonical first line prefix encoding the feed source inside the
// alert detail. It lets the app (and SourceOf) recover source=official_feed
// without a proto change. Example: "[official_feed:nws]".
const markerPrefix = "[official_feed:"
const markerSuffix = "]"

// Severity is the upstream-reported urgency band, normalized across feeds. It
// maps to the proto Priority on the signed event.
type Severity string

const (
	SeverityExtreme  Severity = "extreme"
	SeveritySevere   Severity = "severe"
	SeverityModerate Severity = "moderate"
	SeverityMinor    Severity = "minor"
	SeverityUnknown  Severity = "unknown"
)

// AlertRecord is the normalized, feed-agnostic alert an adapter produces from
// one upstream record. The Ingestor turns it into a cloud-signed
// EMERGENCY_ALERT event. Lat/Lon are the representative point of the affected
// area (WGS84 degrees); an empty NativeID means the adapter could not derive a
// stable id and the record is skipped.
type AlertRecord struct {
	Source    Source
	NativeID  string // upstream-stable id (per feed) used for dedup
	Title     string
	Detail    string
	Severity  Severity
	Lat       float64
	Lon       float64
	OnsetMs   int64 // advisory wall-clock of onset (0 if unknown)
	ExpiresMs int64 // when the alert stops being valid (0 => Ingestor fills a default)
}

// Feed is the pluggable adapter contract. Parse maps the raw upstream bytes
// (fetched by the caller, or a canned fixture in tests) into normalized
// records. It MUST NOT perform network I/O: feeding it bytes is what keeps the
// adapters deterministic and testable offline.
type Feed interface {
	// Source identifies the feed.
	Source() Source
	// URL is the upstream endpoint the scheduler fetches. It is advisory
	// metadata; Parse never calls it.
	URL() string
	// Parse maps raw bytes to normalized alert records. A malformed document
	// returns an error; individual unparseable entries are skipped, not fatal.
	Parse(raw []byte) ([]AlertRecord, error)
}

// Registry returns the default set of feed adapters, keyed by Source.
func Registry() map[Source]Feed {
	list := []Feed{
		NewNWS(),
		NewUSGS(),
		NewWildfire(),
		NewFEMA(),
		NewGDACS(),
	}
	out := make(map[Source]Feed, len(list))
	for _, f := range list {
		out[f.Source()] = f
	}
	return out
}

// AlertID is the namespaced, stable alert id for a record:
// "feed:<source>:<native-id>". Reusing the same id across ingest runs means the
// signed event is byte-identical and dedups by content hash in the store.
func AlertID(src Source, nativeID string) string {
	return fmt.Sprintf("feed:%s:%s", src, nativeID)
}

// decorateDetail prepends the canonical source marker line to a detail string
// so a reader can recover source=official_feed and the feed id. It is
// idempotent: a detail already carrying the marker is returned unchanged.
func decorateDetail(src Source, detail string) string {
	if IsFeed(detail) {
		return detail
	}
	marker := markerPrefix + string(src) + markerSuffix
	if strings.TrimSpace(detail) == "" {
		return marker
	}
	return marker + "\n" + detail
}

// IsFeed reports whether a detail string carries the official_feed marker.
func IsFeed(detail string) bool {
	return strings.HasPrefix(detail, markerPrefix)
}

// SourceOf returns the feed Source encoded in a detail marker and true, or
// ("", false) when the detail is not an official-feed alert.
func SourceOf(detail string) (Source, bool) {
	if !strings.HasPrefix(detail, markerPrefix) {
		return "", false
	}
	end := strings.Index(detail, markerSuffix)
	if end < 0 {
		return "", false
	}
	inner := detail[len(markerPrefix):end]
	if inner == "" {
		return "", false
	}
	return Source(inner), true
}

// severityToPriority maps a normalized severity to the proto Priority. Extreme
// is CRITICAL so the client treats it as a severe alert for notifications.
func severityToPriority(s Severity) resiliencev1.Priority {
	switch s {
	case SeverityExtreme:
		return resiliencev1.Priority_PRIORITY_CRITICAL
	case SeveritySevere:
		return resiliencev1.Priority_PRIORITY_HIGH
	case SeverityModerate:
		return resiliencev1.Priority_PRIORITY_NORMAL
	case SeverityMinor:
		return resiliencev1.Priority_PRIORITY_LOW
	default:
		return resiliencev1.Priority_PRIORITY_NORMAL
	}
}

// BuildBody constructs the EmergencyAlertBody for a record (unsigned). The
// source marker is embedded in the detail; the alert_id is namespaced.
func BuildBody(rec AlertRecord, defaultExpiresMs int64) *resiliencev1.EmergencyAlertBody {
	expires := rec.ExpiresMs
	if expires == 0 {
		expires = defaultExpiresMs
	}
	return &resiliencev1.EmergencyAlertBody{
		AlertId:  AlertID(rec.Source, rec.NativeID),
		Title:    rec.Title,
		Detail:   decorateDetail(rec.Source, rec.Detail),
		Priority: severityToPriority(rec.Severity),
		Area: &resiliencev1.GeoPoint{
			ApproxLat:      rec.Lat,
			ApproxLon:      rec.Lon,
			LocationSource: resiliencev1.LocationSource_LOCATION_SOURCE_ESTIMATED,
		},
		ExpiresMs: expires,
	}
}

// Ingestor signs normalized alert records into cloud-signed EMERGENCY_ALERT
// events using the cloud-service feed key. It is deterministic: given the same
// records and the same key it produces byte-identical events (so re-ingesting
// an unchanged upstream dedups in the store). The feed key is this ingestor's
// identity; clients trust its public key as a root to render feed alerts as
// Official.
type Ingestor struct {
	key ed25519.PrivateKey
	// DefaultTTLMs is applied to records that carry no explicit expiry.
	DefaultTTLMs int64
}

// NewIngestor builds an Ingestor over the cloud feed signing key. ttlMs is the
// fallback expiry window applied to records with no upstream expiry.
func NewIngestor(key ed25519.PrivateKey, ttlMs int64) *Ingestor {
	if ttlMs <= 0 {
		ttlMs = 6 * 60 * 60 * 1000 // 6h default
	}
	return &Ingestor{key: key, DefaultTTLMs: ttlMs}
}

// PublicKeyHex returns the lowercase-hex Ed25519 public key clients must trust
// as a root to label this ingestor's alerts Official.
func (in *Ingestor) PublicKeyHex() string {
	pub := in.key.Public().(ed25519.PublicKey)
	return hexLower(pub)
}

// SignRecord turns one normalized record into a signed EMERGENCY_ALERT event.
// nowMs stamps the header created_at and anchors the default expiry window; it
// is a parameter (not time.Now) so tests are deterministic. lamport is the feed
// key's logical clock value for this event.
func (in *Ingestor) SignRecord(rec AlertRecord, lamport uint64, nowMs int64) (*resiliencev1.SignedEvent, error) {
	body := BuildBody(rec, nowMs+in.DefaultTTLMs)
	bodyBytes, err := proto.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("marshal alert body: %w", err)
	}
	header := &resiliencev1.EventHeader{
		Type:          resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT,
		Lamport:       lamport,
		CreatedAtMs:   nowMs,
		SchemaVersion: 1,
	}
	return events.BuildSignedEvent(header, bodyBytes, in.key)
}

// SignAll signs a slice of records, assigning each a distinct, increasing
// lamport starting at startLamport. Records are sorted by (source, native id)
// first so the lamport assignment is deterministic regardless of adapter
// iteration order. It returns the signed events in the same order.
func (in *Ingestor) SignAll(records []AlertRecord, startLamport uint64, nowMs int64) ([]*resiliencev1.SignedEvent, error) {
	sorted := append([]AlertRecord(nil), records...)
	sort.SliceStable(sorted, func(i, j int) bool {
		if sorted[i].Source != sorted[j].Source {
			return sorted[i].Source < sorted[j].Source
		}
		return sorted[i].NativeID < sorted[j].NativeID
	})
	out := make([]*resiliencev1.SignedEvent, 0, len(sorted))
	lamport := startLamport
	for _, rec := range sorted {
		if rec.NativeID == "" {
			continue
		}
		lamport++
		ev, err := in.SignRecord(rec, lamport, nowMs)
		if err != nil {
			return nil, err
		}
		out = append(out, ev)
	}
	return out, nil
}

const hexDigits = "0123456789abcdef"

func hexLower(b []byte) string {
	var sb strings.Builder
	sb.Grow(len(b) * 2)
	for _, c := range b {
		sb.WriteByte(hexDigits[c>>4])
		sb.WriteByte(hexDigits[c&0x0f])
	}
	return sb.String()
}
