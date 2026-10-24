// Package ai implements the AI assist subsystem for the Resilience Network.
//
// The subsystem augments the emergency coordination system with five
// capabilities (spec §67): freeform-report-to-structured-event, translation,
// summarization, duplicate-report detection, and supply/demand matching
// rationale. It is explicitly designed so the core system works WITHOUT AI:
// every capability has a deterministic, network-free offline fallback
// implemented by [RulesAssistant]. The online path, [BedrockAssistant], calls
// Amazon Bedrock (region us-east-1) via aws-sdk-go-v2.
//
// Contract for callers: the Assistant methods return an error when the online
// model is unreachable or returns unparseable output. Callers MUST handle that
// error by falling back to the deterministic [RulesAssistant] so the system
// keeps functioning. The HTTP API in internal/api does exactly this and marks
// such responses with degraded:true.
package ai

import "context"

// Priority is a coarse urgency band for a structured report.
type Priority string

const (
	PriorityHigh   Priority = "high"
	PriorityMedium Priority = "medium"
	PriorityLow    Priority = "low"
)

// StructuredReport is the structured suggestion derived from free text. The
// Category is a canonical ResourceCategory enum name (without the
// RESOURCE_CATEGORY_ prefix), e.g. "MEDICINE", "MEDICAL_HELP", "WATER".
type StructuredReport struct {
	Category       string   `json:"category"`
	Priority       Priority `json:"priority"`
	ShortTitle     string   `json:"short_title"`
	NormalizedNote string   `json:"normalized_note"`
}

// Translation is the result of a translation request. When Translated is
// false, Text is the original text unchanged (offline fallback: no fake
// translation; the UI shows "translation unavailable offline").
type Translation struct {
	Text       string `json:"text"`
	From       string `json:"from"`
	To         string `json:"to"`
	Translated bool   `json:"translated"`
}

// DupHit is a candidate duplicate of a report with a similarity score in
// [0,1]. Index refers to the position in the existing-reports slice passed to
// Dedup.
type DupHit struct {
	Index int     `json:"index"`
	Text  string  `json:"text"`
	Score float64 `json:"score"`
}

// Assistant is the AI assist contract. Both the online [BedrockAssistant] and
// the offline [RulesAssistant] implement it, so the cloud degraded path
// behaves identically to the Dart LocalRulesAiClient.
//
// Callers must treat a non-nil error as "AI unavailable" and fall back to the
// deterministic rules path rather than failing the request.
type Assistant interface {
	// Structure turns free text into a structured report suggestion. langHint
	// is an optional ISO-639-1 hint ("en", "es") and may be empty.
	Structure(ctx context.Context, text, langHint string) (StructuredReport, error)

	// Translate translates text from one language to another (ISO-639-1 codes).
	Translate(ctx context.Context, text, from, to string) (Translation, error)

	// Summarize produces a 1-3 sentence summary of the given items.
	Summarize(ctx context.Context, items []string) (string, error)

	// Dedup returns likely duplicates of candidate among existing, ordered by
	// descending score.
	Dedup(ctx context.Context, candidate string, existing []string) ([]DupHit, error)
}
