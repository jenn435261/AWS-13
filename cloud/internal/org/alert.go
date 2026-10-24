package org

import (
	"encoding/hex"
	"sort"
	"strings"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"google.golang.org/protobuf/proto"
)

// TrustedOrgs is the set of Ed25519 public keys (lowercase hex) the server
// recognizes as VERIFIED organizations / first responders.
//
// In production this maps to a verified-org certificate chain; for the
// hackathon it is a simple allow-set loaded from the ORG_TRUSTED_PUBKEYS env
// var (comma-separated lowercase hex pubkeys).
//
// The server never BUILDS an EMERGENCY_ALERT itself — an org must sign its
// alert client-side with its own key. The server's job is to validate that an
// incoming alert was signed by a trusted org before accepting it into the store
// via the normal /v1/events path (see [ValidateAlert]).
type TrustedOrgs struct {
	keys map[string]struct{}
}

// NewTrustedOrgs builds a TrustedOrgs from a list of hex-encoded pubkeys.
// Entries are normalized to lowercase and trimmed; empty entries are ignored.
func NewTrustedOrgs(pubkeysHex []string) *TrustedOrgs {
	t := &TrustedOrgs{keys: make(map[string]struct{}, len(pubkeysHex))}
	for _, k := range pubkeysHex {
		k = strings.ToLower(strings.TrimSpace(k))
		if k == "" {
			continue
		}
		t.keys[k] = struct{}{}
	}
	return t
}

// ParseTrustedOrgs parses a comma-separated env value (as in ORG_TRUSTED_PUBKEYS)
// into a TrustedOrgs set.
func ParseTrustedOrgs(csv string) *TrustedOrgs {
	return NewTrustedOrgs(strings.Split(csv, ","))
}

// IsVerifiedOrg reports whether pubkeyHex belongs to a configured trusted org.
// Comparison is case-insensitive on the hex encoding.
func (t *TrustedOrgs) IsVerifiedOrg(pubkeyHex string) bool {
	if t == nil {
		return false
	}
	_, ok := t.keys[strings.ToLower(strings.TrimSpace(pubkeyHex))]
	return ok
}

// IsVerifiedOrgKey is the raw-bytes convenience form of IsVerifiedOrg.
func (t *TrustedOrgs) IsVerifiedOrgKey(pubkey []byte) bool {
	return t.IsVerifiedOrg(hex.EncodeToString(pubkey))
}

// Len returns how many trusted orgs are configured.
func (t *TrustedOrgs) Len() int {
	if t == nil {
		return 0
	}
	return len(t.keys)
}

// List returns the configured trusted org pubkeys (lowercase hex), sorted. Used
// for diagnostics/tests.
func (t *TrustedOrgs) List() []string {
	if t == nil {
		return nil
	}
	out := make([]string, 0, len(t.keys))
	for k := range t.keys {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// ValidateAlert checks that ev is a well-formed EMERGENCY_ALERT whose signature
// and content hash verify AND whose author is a trusted verified org. It
// returns true only when the alert may be tagged as authoritative and accepted.
//
// The server never fabricates alerts: it only validates and tags client-signed
// ones. A valid signature from a non-trusted key returns false so the event is
// NOT treated as an authoritative alert.
func (t *TrustedOrgs) ValidateAlert(ev *resiliencev1.SignedEvent) bool {
	if ev == nil || ev.GetHeader() == nil {
		return false
	}
	if ev.GetHeader().GetType() != resiliencev1.EventType_EVENT_TYPE_EMERGENCY_ALERT {
		return false
	}
	if ok, _ := events.VerifyEvent(ev); !ok {
		return false
	}
	return t.IsVerifiedOrgKey(ev.GetHeader().GetAuthorPubkey())
}

// unmarshal is a tiny proto.Unmarshal wrapper kept local to the package so the
// aggregator does not import proto directly at every call site.
func unmarshal(b []byte, m proto.Message) error {
	return proto.Unmarshal(b, m)
}
