package ai

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
)

// fakeInvoker is a test double for the bedrockruntime client. It returns a
// canned Anthropic-style response body (or an error) so no real AWS call is
// made.
type fakeInvoker struct {
	responseText string
	err          error
}

func (f fakeInvoker) InvokeModel(_ context.Context, _ *bedrockruntime.InvokeModelInput, _ ...func(*bedrockruntime.Options)) (*bedrockruntime.InvokeModelOutput, error) {
	if f.err != nil {
		return nil, f.err
	}
	// Anthropic Claude messages response envelope.
	body, _ := json.Marshal(map[string]any{
		"content": []map[string]any{
			{"type": "text", "text": f.responseText},
		},
	})
	return &bedrockruntime.InvokeModelOutput{Body: body}, nil
}

func TestBedrockStructureParsesStrictJSON(t *testing.T) {
	// Model returns strict JSON (optionally wrapped in prose / fences).
	modelOut := "Here you go:\n```json\n" +
		`{"category":"MEDICINE","priority":"high","short_title":"Insulin refrigeration","normalized_note":"Needs refrigerated storage for insulin"}` +
		"\n```"
	b := NewBedrockAssistantWithClient(fakeInvoker{responseText: modelOut}, DefaultModelID)

	got, err := b.Structure(context.Background(), "insulin needs to stay cold", "en")
	if err != nil {
		t.Fatalf("Structure error: %v", err)
	}
	if got.Category != "MEDICINE" || got.Priority != PriorityHigh {
		t.Fatalf("unexpected parse: %+v", got)
	}
	if got.ShortTitle == "" {
		t.Fatalf("expected short_title to be parsed")
	}
}

func TestBedrockStructureRejectsMalformedOutput(t *testing.T) {
	// No JSON object at all -> must error so the API falls back to rules.
	b := NewBedrockAssistantWithClient(
		fakeInvoker{responseText: "I'm not sure how to help with that."}, DefaultModelID)
	if _, err := b.Structure(context.Background(), "whatever", ""); err == nil {
		t.Fatalf("expected error on malformed model output, got nil")
	}
}

func TestBedrockStructureRejectsInvalidCategory(t *testing.T) {
	// Valid JSON shape but an invalid category must be rejected by validation.
	b := NewBedrockAssistantWithClient(
		fakeInvoker{responseText: `{"category":"PIZZA","priority":"high","short_title":"x","normalized_note":"y"}`},
		DefaultModelID)
	if _, err := b.Structure(context.Background(), "whatever", ""); err == nil {
		t.Fatalf("expected error on invalid category, got nil")
	}
}

func TestBedrockInvokeErrorPropagates(t *testing.T) {
	b := NewBedrockAssistantWithClient(
		fakeInvoker{err: errors.New("throttled")}, DefaultModelID)
	if _, err := b.Structure(context.Background(), "whatever", ""); err == nil {
		t.Fatalf("expected the invoke error to propagate so the caller can fall back")
	}
}

func TestModelIDFromEnvDefault(t *testing.T) {
	t.Setenv("BEDROCK_MODEL_ID", "")
	id, configured := ModelIDFromEnv()
	if configured {
		t.Fatalf("expected configured=false when env unset")
	}
	if id != DefaultModelID {
		t.Fatalf("default model id = %q, want %q", id, DefaultModelID)
	}

	t.Setenv("BEDROCK_MODEL_ID", "amazon.titan-text-express-v1")
	id, configured = ModelIDFromEnv()
	if !configured || id != "amazon.titan-text-express-v1" {
		t.Fatalf("env override not honored: id=%q configured=%v", id, configured)
	}
}
