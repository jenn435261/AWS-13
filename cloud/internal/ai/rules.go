package ai

import (
	"context"
	"sort"
	"strings"
	"unicode"
)

// RulesAssistant is the deterministic, network-free offline implementation of
// [Assistant]. It uses keyword/category heuristics and simple token similarity.
//
// This is the SAME logic the Dart LocalRulesAiClient implements, so the cloud
// degraded path and the on-device offline path produce matching results. It is
// always available and never errors.
type RulesAssistant struct{}

// NewRulesAssistant returns a ready-to-use deterministic assistant.
func NewRulesAssistant() *RulesAssistant { return &RulesAssistant{} }

var _ Assistant = (*RulesAssistant)(nil)

// categoryKeyword maps a lowercase keyword/substring to a canonical category.
// Order of evaluation is defined by categoryRules below so the most specific
// match wins deterministically.
type categoryRule struct {
	// substrings any of which, found in the normalized text, select category.
	substrings []string
	category   string
	// highPriority marks categories that are urgent by default.
	highPriority bool
}

// categoryRules is evaluated in order; the first matching rule wins. Medical
// needs are checked first because they are the most urgent and the insulin
// example must resolve to MEDICINE/high.
var categoryRules = []categoryRule{
	{substrings: []string{"insulin", "refrigerat", "refrigerate", "medication", "medicine", "prescription", "pharmacy", "antibiotic", "epipen", "inhaler"}, category: "MEDICINE", highPriority: true},
	{substrings: []string{"injured", "injury", "bleeding", "unconscious", "doctor", "nurse", "medic", "ambulance", "cpr", "wound", "medical help", "medical"}, category: "MEDICAL_HELP", highPriority: true},
	{substrings: []string{"water", "thirsty", "dehydrat", "drinking"}, category: "WATER", highPriority: true},
	{substrings: []string{"food", "hungry", "meal", "eat", "starving", "formula"}, category: "FOOD", highPriority: false},
	{substrings: []string{"shelter", "homeless", "roof", "sleep", "tent", "housing", "evacuat"}, category: "SHELTER", highPriority: true},
	{substrings: []string{"power", "generator", "electricity", "outage", "blackout"}, category: "POWER", highPriority: false},
	{substrings: []string{"charge", "charging", "charger"}, category: "CHARGING", highPriority: false},
	{substrings: []string{"batter"}, category: "BATTERIES", highPriority: false},
	{substrings: []string{"blanket", "cold", "freezing", "warm"}, category: "BLANKETS", highPriority: false},
	{substrings: []string{"ride", "transport", "truck", "car", "drive", "vehicle", "move"}, category: "TRANSPORTATION", highPriority: false},
	{substrings: []string{"radio", "signal", "phone", "comms", "communication", "internet"}, category: "COMMUNICATION", highPriority: false},
	{substrings: []string{"tool", "chainsaw", "shovel", "generator repair"}, category: "TOOLS", highPriority: false},
}

// urgentModifiers raise priority to high regardless of category.
var urgentModifiers = []string{"urgent", "emergency", "immediately", "asap", "dying", "critical", "life", "now", "trapped", "baby", "child", "elderly", "grandmother", "grandfather"}

// Structure implements [Assistant] deterministically.
func (RulesAssistant) Structure(_ context.Context, text, _ string) (StructuredReport, error) {
	norm := strings.ToLower(strings.TrimSpace(text))

	category := "OTHER"
	high := false
	for _, rule := range categoryRules {
		if containsAny(norm, rule.substrings) {
			category = rule.category
			high = rule.highPriority
			break
		}
	}

	priority := PriorityMedium
	if high {
		priority = PriorityHigh
	}
	if containsAny(norm, urgentModifiers) {
		priority = PriorityHigh
	}
	if category == "OTHER" && !containsAny(norm, urgentModifiers) {
		priority = PriorityLow
	}

	return StructuredReport{
		Category:       category,
		Priority:       priority,
		ShortTitle:     shortTitle(text, category),
		NormalizedNote: normalizeWhitespace(text),
	}, nil
}

// Translate implements [Assistant]. Offline there is no translation model, so
// it returns the original text with Translated=false.
func (RulesAssistant) Translate(_ context.Context, text, from, to string) (Translation, error) {
	return Translation{
		Text:       text,
		From:       from,
		To:         to,
		Translated: false,
	}, nil
}

// Summarize implements [Assistant] with a deterministic extractive summary:
// it keeps the most recent items (assumed appended last) and truncates to at
// most three sentences.
func (RulesAssistant) Summarize(_ context.Context, items []string) (string, error) {
	cleaned := make([]string, 0, len(items))
	for _, it := range items {
		it = normalizeWhitespace(it)
		if it != "" {
			cleaned = append(cleaned, it)
		}
	}
	if len(cleaned) == 0 {
		return "No reports to summarize.", nil
	}
	// Most recent first (last appended is treated as newest), capped at 3.
	n := len(cleaned)
	keep := make([]string, 0, 3)
	for i := n - 1; i >= 0 && len(keep) < 3; i-- {
		keep = append(keep, cleaned[i])
	}
	summary := strings.Join(keep, " ")
	// Ensure terminal punctuation for readability.
	if !strings.HasSuffix(summary, ".") && !strings.HasSuffix(summary, "!") && !strings.HasSuffix(summary, "?") {
		summary += "."
	}
	return summary, nil
}

// Dedup implements [Assistant] with token Jaccard similarity. Hits with a
// score >= dedupThreshold are returned, highest first.
func (RulesAssistant) Dedup(_ context.Context, candidate string, existing []string) ([]DupHit, error) {
	candTokens := tokenize(candidate)
	hits := make([]DupHit, 0)
	for i, ex := range existing {
		score := jaccard(candTokens, tokenize(ex))
		if score >= dedupThreshold {
			hits = append(hits, DupHit{Index: i, Text: ex, Score: score})
		}
	}
	sort.SliceStable(hits, func(a, b int) bool {
		if hits[a].Score != hits[b].Score {
			return hits[a].Score > hits[b].Score
		}
		return hits[a].Index < hits[b].Index
	})
	return hits, nil
}

// dedupThreshold is the minimum Jaccard similarity to treat two reports as
// likely duplicates. Chosen so obvious paraphrases flag but unrelated items do
// not.
const dedupThreshold = 0.5

// containsAny reports whether s contains any of the substrings.
func containsAny(s string, subs []string) bool {
	for _, sub := range subs {
		if strings.Contains(s, sub) {
			return true
		}
	}
	return false
}

// shortTitle produces a concise human title from the text and category.
func shortTitle(text, category string) string {
	norm := normalizeWhitespace(text)
	words := strings.Fields(norm)
	const maxWords = 6
	if len(words) > maxWords {
		words = words[:maxWords]
		norm = strings.Join(words, " ") + "..."
	} else {
		norm = strings.Join(words, " ")
	}
	if norm == "" {
		return titleCase(category)
	}
	return norm
}

func titleCase(category string) string {
	parts := strings.Split(strings.ToLower(category), "_")
	for i, p := range parts {
		if p == "" {
			continue
		}
		parts[i] = strings.ToUpper(p[:1]) + p[1:]
	}
	return strings.Join(parts, " ")
}

// normalizeWhitespace collapses runs of whitespace and trims the string.
func normalizeWhitespace(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

// tokenize lowercases, strips punctuation, and splits into a set of tokens.
func tokenize(s string) map[string]struct{} {
	set := make(map[string]struct{})
	for _, f := range strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsNumber(r)
	}) {
		if _, stop := stopwords[f]; stop {
			continue
		}
		set[f] = struct{}{}
	}
	return set
}

// stopwords are ignored for similarity so function words do not inflate scores.
var stopwords = map[string]struct{}{
	"a": {}, "an": {}, "the": {}, "and": {}, "or": {}, "to": {}, "of": {},
	"in": {}, "on": {}, "at": {}, "for": {}, "is": {}, "are": {}, "my": {},
	"i": {}, "we": {}, "need": {}, "needs": {}, "with": {}, "some": {},
}

// jaccard computes the Jaccard similarity of two token sets.
func jaccard(a, b map[string]struct{}) float64 {
	if len(a) == 0 && len(b) == 0 {
		return 0
	}
	inter := 0
	for t := range a {
		if _, ok := b[t]; ok {
			inter++
		}
	}
	union := len(a) + len(b) - inter
	if union == 0 {
		return 0
	}
	return float64(inter) / float64(union)
}
