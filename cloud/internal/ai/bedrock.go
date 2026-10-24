package ai

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
)

// defaultRegion is the hackathon's locked region.
const defaultRegion = "us-east-1"

// DefaultModelID is the default Bedrock model. Current Claude models on
// Bedrock require an INFERENCE PROFILE id (the "us." cross-region prefix) for
// on-demand invocation — a raw foundation-model id returns a ValidationException
// ("on-demand throughput isn't supported"). This profile id was validated live
// against the hackathon us-east-1 account. Override via BEDROCK_MODEL_ID;
// Amazon Titan and Nova ids are also supported (see modelFamily).
const DefaultModelID = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"

// invoker is the minimal slice of the bedrockruntime client that
// BedrockAssistant depends on. Unit tests supply a fake implementation so no
// real AWS call is ever made.
type invoker interface {
	InvokeModel(ctx context.Context, params *bedrockruntime.InvokeModelInput, optFns ...func(*bedrockruntime.Options)) (*bedrockruntime.InvokeModelOutput, error)
}

// BedrockAssistant is the online [Assistant] backed by Amazon Bedrock. On any
// error (unreachable model, malformed output) the HTTP API falls back to
// [RulesAssistant].
type BedrockAssistant struct {
	client  invoker
	modelID string
}

var _ Assistant = (*BedrockAssistant)(nil)

// ModelID returns the configured Bedrock model id.
func (b *BedrockAssistant) ModelID() string { return b.modelID }

// ModelIDFromEnv returns BEDROCK_MODEL_ID or DefaultModelID. It also reports
// whether the env var was explicitly set, which the API uses to decide whether
// to attempt the online path at all.
func ModelIDFromEnv() (id string, configured bool) {
	if v := strings.TrimSpace(os.Getenv("BEDROCK_MODEL_ID")); v != "" {
		return v, true
	}
	return DefaultModelID, false
}

// NewBedrockAssistant builds a BedrockAssistant using the AWS default config
// (credentials chain + region). Region defaults to us-east-1 unless AWS_REGION
// is set. The model id comes from BEDROCK_MODEL_ID or DefaultModelID.
//
// This constructor loads AWS config and so should only be called when the
// online path is actually desired. Tests use NewBedrockAssistantWithClient with
// a fake to avoid any AWS contact.
func NewBedrockAssistant(ctx context.Context) (*BedrockAssistant, error) {
	region := strings.TrimSpace(os.Getenv("AWS_REGION"))
	if region == "" {
		region = defaultRegion
	}
	cfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	modelID, _ := ModelIDFromEnv()
	return &BedrockAssistant{
		client:  bedrockruntime.NewFromConfig(cfg),
		modelID: modelID,
	}, nil
}

// NewBedrockAssistantWithClient builds a BedrockAssistant over an explicit
// invoker (used by tests with a fake) and model id. If modelID is empty the
// default is used.
func NewBedrockAssistantWithClient(client invoker, modelID string) *BedrockAssistant {
	if strings.TrimSpace(modelID) == "" {
		modelID = DefaultModelID
	}
	return &BedrockAssistant{client: client, modelID: modelID}
}

// modelFamily classifies a model id so the request/response body shapes match
// the provider's contract.
type modelFamily int

const (
	familyAnthropic modelFamily = iota
	familyTitan
	familyNova
)

func familyOf(modelID string) modelFamily {
	id := strings.ToLower(modelID)
	switch {
	case strings.Contains(id, "titan"):
		return familyTitan
	case strings.Contains(id, "nova"):
		return familyNova
	default:
		// Anthropic Claude (and compatible) is the default.
		return familyAnthropic
	}
}

// invokeText sends a single-prompt inference and returns the model's text
// completion, abstracting away the per-family request/response envelope.
func (b *BedrockAssistant) invokeText(ctx context.Context, system, user string) (string, error) {
	body, err := b.buildRequestBody(system, user)
	if err != nil {
		return "", err
	}
	out, err := b.client.InvokeModel(ctx, &bedrockruntime.InvokeModelInput{
		ModelId:     aws.String(b.modelID),
		Body:        body,
		ContentType: aws.String("application/json"),
		Accept:      aws.String("application/json"),
	})
	if err != nil {
		return "", fmt.Errorf("bedrock invoke: %w", err)
	}
	return b.parseResponseBody(out.Body)
}

func (b *BedrockAssistant) buildRequestBody(system, user string) ([]byte, error) {
	switch familyOf(b.modelID) {
	case familyTitan:
		// Amazon Titan Text.
		return json.Marshal(map[string]any{
			"inputText": system + "\n\n" + user,
			"textGenerationConfig": map[string]any{
				"maxTokenCount": 512,
				"temperature":   0,
			},
		})
	case familyNova:
		// Amazon Nova messages API.
		return json.Marshal(map[string]any{
			"system": []map[string]any{{"text": system}},
			"messages": []map[string]any{
				{"role": "user", "content": []map[string]any{{"text": user}}},
			},
			"inferenceConfig": map[string]any{"maxTokens": 512, "temperature": 0},
		})
	default:
		// Anthropic Claude messages API.
		return json.Marshal(map[string]any{
			"anthropic_version": "bedrock-2023-05-31",
			"max_tokens":        512,
			"temperature":       0,
			"system":            system,
			"messages": []map[string]any{
				{"role": "user", "content": []map[string]any{{"type": "text", "text": user}}},
			},
		})
	}
}

// parseResponseBody extracts the generated text from a provider response body.
func (b *BedrockAssistant) parseResponseBody(raw []byte) (string, error) {
	switch familyOf(b.modelID) {
	case familyTitan:
		var r struct {
			Results []struct {
				OutputText string `json:"outputText"`
			} `json:"results"`
		}
		if err := json.Unmarshal(raw, &r); err != nil {
			return "", fmt.Errorf("parse titan response: %w", err)
		}
		if len(r.Results) == 0 {
			return "", errors.New("titan response has no results")
		}
		return r.Results[0].OutputText, nil
	case familyNova:
		var r struct {
			Output struct {
				Message struct {
					Content []struct {
						Text string `json:"text"`
					} `json:"content"`
				} `json:"message"`
			} `json:"output"`
		}
		if err := json.Unmarshal(raw, &r); err != nil {
			return "", fmt.Errorf("parse nova response: %w", err)
		}
		if len(r.Output.Message.Content) == 0 {
			return "", errors.New("nova response has no content")
		}
		return r.Output.Message.Content[0].Text, nil
	default:
		var r struct {
			Content []struct {
				Type string `json:"type"`
				Text string `json:"text"`
			} `json:"content"`
		}
		if err := json.Unmarshal(raw, &r); err != nil {
			return "", fmt.Errorf("parse anthropic response: %w", err)
		}
		for _, c := range r.Content {
			if c.Text != "" {
				return c.Text, nil
			}
		}
		return "", errors.New("anthropic response has no text content")
	}
}

// extractJSON pulls the first top-level JSON object out of a model completion,
// tolerating surrounding prose or markdown code fences.
func extractJSON(s string) (string, error) {
	s = strings.TrimSpace(s)
	// Strip a leading ```json / ``` fence if present.
	if strings.HasPrefix(s, "```") {
		if i := strings.IndexByte(s, '\n'); i >= 0 {
			s = s[i+1:]
		}
		s = strings.TrimSuffix(strings.TrimSpace(s), "```")
		s = strings.TrimSpace(s)
	}
	start := strings.IndexByte(s, '{')
	end := strings.LastIndexByte(s, '}')
	if start < 0 || end < 0 || end < start {
		return "", errors.New("no JSON object found in model output")
	}
	return s[start : end+1], nil
}

// --- Assistant implementation ---

const structureSystem = `You convert a free-text emergency report into a single strict JSON object and nothing else.
Fields:
  "category": one of WATER, FOOD, MEDICINE, SHELTER, POWER, TRANSPORTATION, MEDICAL_HELP, COMMUNICATION, BLANKETS, BATTERIES, CHARGING, TOOLS, OTHER
  "priority": one of high, medium, low
  "short_title": a concise title (max ~8 words)
  "normalized_note": a cleaned one-line restatement of the need
Return ONLY the JSON object.`

// Structure implements [Assistant] via the model, validating strict JSON.
func (b *BedrockAssistant) Structure(ctx context.Context, text, langHint string) (StructuredReport, error) {
	user := text
	if strings.TrimSpace(langHint) != "" {
		user = fmt.Sprintf("(language hint: %s)\n%s", langHint, text)
	}
	out, err := b.invokeText(ctx, structureSystem, user)
	if err != nil {
		return StructuredReport{}, err
	}
	js, err := extractJSON(out)
	if err != nil {
		return StructuredReport{}, err
	}
	var sr StructuredReport
	dec := json.NewDecoder(strings.NewReader(js))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&sr); err != nil {
		return StructuredReport{}, fmt.Errorf("parse structured report: %w", err)
	}
	if err := validateStructured(&sr); err != nil {
		return StructuredReport{}, err
	}
	return sr, nil
}

var validCategories = map[string]struct{}{
	"WATER": {}, "FOOD": {}, "MEDICINE": {}, "SHELTER": {}, "POWER": {},
	"TRANSPORTATION": {}, "MEDICAL_HELP": {}, "COMMUNICATION": {}, "BLANKETS": {},
	"BATTERIES": {}, "CHARGING": {}, "TOOLS": {}, "OTHER": {},
}

func validateStructured(sr *StructuredReport) error {
	sr.Category = strings.ToUpper(strings.TrimSpace(sr.Category))
	if _, ok := validCategories[sr.Category]; !ok {
		return fmt.Errorf("invalid category %q", sr.Category)
	}
	switch sr.Priority {
	case PriorityHigh, PriorityMedium, PriorityLow:
	default:
		return fmt.Errorf("invalid priority %q", sr.Priority)
	}
	if strings.TrimSpace(sr.ShortTitle) == "" {
		return errors.New("empty short_title")
	}
	return nil
}

const translateSystemTmpl = `Translate the user's message from %s to %s.
Return ONLY a strict JSON object: {"text": "<translation>"}. No commentary.`

// Translate implements [Assistant] via the model. On success Translated=true.
func (b *BedrockAssistant) Translate(ctx context.Context, text, from, to string) (Translation, error) {
	sys := fmt.Sprintf(translateSystemTmpl, langName(from), langName(to))
	out, err := b.invokeText(ctx, sys, text)
	if err != nil {
		return Translation{}, err
	}
	js, err := extractJSON(out)
	if err != nil {
		return Translation{}, err
	}
	var r struct {
		Text string `json:"text"`
	}
	if err := json.Unmarshal([]byte(js), &r); err != nil {
		return Translation{}, fmt.Errorf("parse translation: %w", err)
	}
	if strings.TrimSpace(r.Text) == "" {
		return Translation{}, errors.New("empty translation")
	}
	return Translation{Text: r.Text, From: from, To: to, Translated: true}, nil
}

func langName(code string) string {
	switch strings.ToLower(strings.TrimSpace(code)) {
	case "en":
		return "English"
	case "es":
		return "Spanish"
	case "":
		return "the source language"
	default:
		return code
	}
}

const summarizeSystem = `Summarize the following emergency reports in 1 to 3 sentences, focusing on the most important and most recent changes. Return ONLY the summary text, no preamble.`

// Summarize implements [Assistant] via the model.
func (b *BedrockAssistant) Summarize(ctx context.Context, items []string) (string, error) {
	if len(items) == 0 {
		return "No reports to summarize.", nil
	}
	var sb strings.Builder
	for i, it := range items {
		fmt.Fprintf(&sb, "%d. %s\n", i+1, it)
	}
	out, err := b.invokeText(ctx, summarizeSystem, sb.String())
	if err != nil {
		return "", err
	}
	out = strings.TrimSpace(out)
	if out == "" {
		return "", errors.New("empty summary")
	}
	return out, nil
}

const dedupSystem = `You detect duplicate emergency reports. Given a candidate report and a numbered list of existing reports, identify which existing reports describe the same need.
Return ONLY a strict JSON object: {"hits":[{"index": <0-based index into the existing list>, "score": <0.0-1.0 similarity>}]}. Include only indices with score >= 0.5. If none, return {"hits":[]}.`

// Dedup implements [Assistant] via the model, validating strict JSON.
func (b *BedrockAssistant) Dedup(ctx context.Context, candidate string, existing []string) ([]DupHit, error) {
	if len(existing) == 0 {
		return nil, nil
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "Candidate: %s\n\nExisting:\n", candidate)
	for i, it := range existing {
		fmt.Fprintf(&sb, "%d. %s\n", i, it)
	}
	out, err := b.invokeText(ctx, dedupSystem, sb.String())
	if err != nil {
		return nil, err
	}
	js, err := extractJSON(out)
	if err != nil {
		return nil, err
	}
	var r struct {
		Hits []struct {
			Index int     `json:"index"`
			Score float64 `json:"score"`
		} `json:"hits"`
	}
	if err := json.Unmarshal([]byte(js), &r); err != nil {
		return nil, fmt.Errorf("parse dedup hits: %w", err)
	}
	hits := make([]DupHit, 0, len(r.Hits))
	for _, h := range r.Hits {
		if h.Index < 0 || h.Index >= len(existing) {
			return nil, fmt.Errorf("dedup index %d out of range", h.Index)
		}
		hits = append(hits, DupHit{Index: h.Index, Text: existing[h.Index], Score: h.Score})
	}
	return hits, nil
}
