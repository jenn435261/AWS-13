package store

import (
	"encoding/hex"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"google.golang.org/protobuf/proto"
)

// eventLatLon extracts a representative (lat, lon) for the event so it can be
// stored in the PostGIS geography column for later "within N km" queries.
//
// Bodies are opaque bytes typed by header.type, so we decode the known
// geo-carrying body for the event type and prefer the approximate coordinates
// (the always-safe-to-share values). Returns (false, 0, 0) when the event
// carries no usable location.
func eventLatLon(ev *resiliencev1.SignedEvent) (bool, float64, float64) {
	h := ev.GetHeader()
	if h == nil {
		return false, 0, 0
	}
	body := ev.GetBody()

	var gp *resiliencev1.GeoPoint
	switch h.GetType() {
	case resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
		resiliencev1.EventType_EVENT_TYPE_SHELTER_CREATED:
		var b resiliencev1.ResourceBody
		if proto.Unmarshal(body, &b) == nil {
			gp = b.GetLocation()
		}
	case resiliencev1.EventType_EVENT_TYPE_HELP_REQUESTED:
		var b resiliencev1.HelpRequestBody
		if proto.Unmarshal(body, &b) == nil {
			gp = b.GetLocation()
		}
	case resiliencev1.EventType_EVENT_TYPE_HELP_OFFERED:
		var b resiliencev1.HelpOfferBody
		if proto.Unmarshal(body, &b) == nil {
			gp = b.GetLocation()
		}
	case resiliencev1.EventType_EVENT_TYPE_TRANSPORT_OFFERED:
		var b resiliencev1.TransportOfferBody
		if proto.Unmarshal(body, &b) == nil {
			gp = b.GetLocation()
		}
	case resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT:
		var b resiliencev1.EmergencyAlertBody
		if proto.Unmarshal(body, &b) == nil {
			gp = b.GetArea()
		}
	default:
		return false, 0, 0
	}

	return geoPointLatLon(gp)
}

func geoPointLatLon(gp *resiliencev1.GeoPoint) (bool, float64, float64) {
	if gp == nil {
		return false, 0, 0
	}
	if gp.GetHasExact() && (gp.GetExactLat() != 0 || gp.GetExactLon() != 0) {
		return true, gp.GetExactLat(), gp.GetExactLon()
	}
	if gp.GetApproxLat() != 0 || gp.GetApproxLon() != 0 {
		return true, gp.GetApproxLat(), gp.GetApproxLon()
	}
	return false, 0, 0
}

func hexDecode(s string) ([]byte, error) {
	return hex.DecodeString(s)
}
