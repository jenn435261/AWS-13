package ai

import (
	"context"
	"os"
	"testing"
	"time"
)

// TestBedrockIntegration exercises the REAL Bedrock path. It is skipped unless
// RESILIENCE_BEDROCK=1 and AWS credentials are present in the environment, so
// the normal `go test ./...` never contacts AWS. Run it with:
//
//	RESILIENCE_BEDROCK=1 go test ./internal/ai/ -run TestBedrockIntegration -v
//
// (requires AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN and
// AWS_REGION=us-east-1, plus Bedrock model access to the default inference
// profile or one set via BEDROCK_MODEL_ID).
func TestBedrockIntegration(t *testing.T) {
	if os.Getenv("RESILIENCE_BEDROCK") != "1" {
		t.Skip("set RESILIENCE_BEDROCK=1 (with AWS creds) to run the live Bedrock test")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	a, err := NewBedrockAssistant(ctx)
	if err != nil {
		t.Fatalf("NewBedrockAssistant: %v", err)
	}

	t.Run("structure", func(t *testing.T) {
		sr, err := a.Structure(ctx,
			"my grandmother needs somewhere to keep her insulin cold", "en")
		if err != nil {
			t.Fatalf("Structure: %v", err)
		}
		if _, ok := validCategories[sr.Category]; !ok {
			t.Fatalf("model returned invalid category %q", sr.Category)
		}
		if sr.ShortTitle == "" {
			t.Fatalf("empty short_title")
		}
		t.Logf("structured: %+v", sr)
	})

	t.Run("translate", func(t *testing.T) {
		tr, err := a.Translate(ctx, "I need water for three people", "en", "es")
		if err != nil {
			t.Fatalf("Translate: %v", err)
		}
		if !tr.Translated || tr.Text == "" {
			t.Fatalf("expected a real translation, got %+v", tr)
		}
		t.Logf("translation: %q", tr.Text)
	})

	t.Run("summarize", func(t *testing.T) {
		s, err := a.Summarize(ctx, []string{
			"Water available at the community center.",
			"5th street is blocked by debris.",
			"Shelter 18 opened with 40 beds.",
		})
		if err != nil {
			t.Fatalf("Summarize: %v", err)
		}
		if s == "" {
			t.Fatalf("empty summary")
		}
		t.Logf("summary: %s", s)
	})
}
