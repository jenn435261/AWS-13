package syncserver

import (
	resiliencev1 "github.com/resilience-network/aws13/node/gen/resilience/v1"
	"google.golang.org/protobuf/proto"
)

// State is the folded, web-app-friendly view of the current world derived from
// the stored events. It intentionally exposes only coarse, shareable fields:
// no exact coordinates, no author identities, no message contents.
type State struct {
	Resources []ResourceView `json:"resources"`
	Alerts    []AlertView    `json:"alerts"`
	Requests  []RequestView  `json:"requests"`
	Count     int            `json:"count"` // total events folded
}

// ResourceView is a single current resource.
type ResourceView struct {
	ID           string `json:"id"`
	Category     string `json:"category"`
	Title        string `json:"title"`
	Notes        string `json:"notes,omitempty"`
	Amount       string `json:"amount"`
	Availability string `json:"availability"`
	IsShelter    bool   `json:"is_shelter"`
	H3Cell       uint64 `json:"h3_cell,omitempty"`
	UpdatedAtMs  int64  `json:"updated_at_ms"`
}

// AlertView is a single current emergency alert.
type AlertView struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Detail    string `json:"detail,omitempty"`
	Priority  string `json:"priority"`
	CreatedMs int64  `json:"created_ms"`
	ExpiresMs int64  `json:"expires_ms,omitempty"`
}

// RequestView is a single open help request (coarse view).
type RequestView struct {
	ID        string `json:"id"`
	Freeform  string `json:"freeform,omitempty"`
	Priority  string `json:"priority"`
	CreatedMs int64  `json:"created_ms"`
	H3Cell    uint64 `json:"h3_cell,omitempty"`
}

// FoldState replays the ordered events into the current State. Resources are
// keyed by their stable resource id (falling back to the event id) so that an
// UPDATED event supersedes the CREATED one. Events arrive ordered by (author,
// lamport, id); for a single resource the last write wins by lamport.
func FoldState(evs []*resiliencev1.SignedEvent) State {
	resByID := map[string]ResourceView{}
	resLamport := map[string]uint64{}
	alertByID := map[string]AlertView{}
	reqByID := map[string]RequestView{}

	for _, ev := range evs {
		h := ev.GetHeader()
		if h == nil {
			continue
		}
		switch h.GetType() {
		case resiliencev1.EventType_EVENT_TYPE_RESOURCE_CREATED,
			resiliencev1.EventType_EVENT_TYPE_RESOURCE_UPDATED:
			var b resiliencev1.ResourceBody
			if proto.Unmarshal(ev.GetBody(), &b) != nil {
				continue
			}
			id := b.GetResourceId()
			if id == "" {
				id = hexID(h.GetEventId())
			}
			if prev, ok := resLamport[id]; ok && h.GetLamport() < prev {
				continue // older update, ignore
			}
			resLamport[id] = h.GetLamport()
			resByID[id] = ResourceView{
				ID:           id,
				Category:     b.GetCategory().String(),
				Title:        b.GetTitle(),
				Notes:        b.GetNotes(),
				Amount:       b.GetAmount().String(),
				Availability: b.GetAvailability().String(),
				IsShelter:    b.GetIsShelter(),
				H3Cell:       h.GetH3Cell(),
				UpdatedAtMs:  h.GetCreatedAtMs(),
			}
		case resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT:
			var b resiliencev1.EmergencyAlertBody
			if proto.Unmarshal(ev.GetBody(), &b) != nil {
				continue
			}
			id := b.GetAlertId()
			if id == "" {
				id = hexID(h.GetEventId())
			}
			alertByID[id] = AlertView{
				ID:        id,
				Title:     b.GetTitle(),
				Detail:    b.GetDetail(),
				Priority:  b.GetPriority().String(),
				CreatedMs: h.GetCreatedAtMs(),
				ExpiresMs: b.GetExpiresMs(),
			}
		case resiliencev1.EventType_EVENT_TYPE_HELP_REQUESTED:
			var b resiliencev1.HelpRequestBody
			if proto.Unmarshal(ev.GetBody(), &b) != nil {
				continue
			}
			id := b.GetRequestId()
			if id == "" {
				id = hexID(h.GetEventId())
			}
			reqByID[id] = RequestView{
				ID:        id,
				Freeform:  b.GetFreeform(),
				Priority:  b.GetPriority().String(),
				CreatedMs: h.GetCreatedAtMs(),
				H3Cell:    h.GetH3Cell(),
			}
		}
	}

	st := State{Count: len(evs)}
	st.Resources = make([]ResourceView, 0, len(resByID))
	for _, v := range resByID {
		st.Resources = append(st.Resources, v)
	}
	st.Alerts = make([]AlertView, 0, len(alertByID))
	for _, v := range alertByID {
		st.Alerts = append(st.Alerts, v)
	}
	st.Requests = make([]RequestView, 0, len(reqByID))
	for _, v := range reqByID {
		st.Requests = append(st.Requests, v)
	}
	sortState(&st)
	return st
}

func sortState(st *State) {
	// Deterministic output: sort each slice by id.
	sortResources(st.Resources)
	sortAlerts(st.Alerts)
	sortRequests(st.Requests)
}

func sortResources(s []ResourceView) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j-1].ID > s[j].ID; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}

func sortAlerts(s []AlertView) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j-1].ID > s[j].ID; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}

func sortRequests(s []RequestView) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j-1].ID > s[j].ID; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}
