package ai

import (
	"context"
	"testing"
)

func TestRulesStructureInsulinExample(t *testing.T) {
	r := NewRulesAssistant()
	got, err := r.Structure(context.Background(),
		"my grandmother needs somewhere to keep her insulin cold", "en")
	if err != nil {
		t.Fatalf("Structure error: %v", err)
	}
	if got.Category != "MEDICINE" {
		t.Fatalf("category = %q, want MEDICINE", got.Category)
	}
	if got.Priority != PriorityHigh {
		t.Fatalf("priority = %q, want high", got.Priority)
	}
	if got.NormalizedNote == "" || got.ShortTitle == "" {
		t.Fatalf("expected non-empty title/note, got %+v", got)
	}
}

func TestRulesStructureCategories(t *testing.T) {
	r := NewRulesAssistant()
	cases := map[string]string{
		"we have no drinking water left":        "WATER",
		"need food, the kids are hungry":          "FOOD",
		"someone is bleeding and unconscious":     "MEDICAL_HELP",
		"our shelter roof collapsed":              "SHELTER",
		"the power is out, need a generator":      "POWER",
		"can anyone give us a ride out of here":   "TRANSPORTATION",
		"asdf qwer zxcv":                          "OTHER",
	}
	for text, want := range cases {
		got, err := r.Structure(context.Background(), text, "")
		if err != nil {
			t.Fatalf("Structure(%q) error: %v", text, err)
		}
		if got.Category != want {
			t.Errorf("Structure(%q) category = %q, want %q", text, got.Category, want)
		}
	}
}

func TestRulesStructureIsDeterministic(t *testing.T) {
	r := NewRulesAssistant()
	a, _ := r.Structure(context.Background(), "need insulin refrigerated", "")
	b, _ := r.Structure(context.Background(), "need insulin refrigerated", "")
	if a != b {
		t.Fatalf("non-deterministic: %+v vs %+v", a, b)
	}
}

func TestRulesTranslateOfflineReturnsOriginalDegraded(t *testing.T) {
	r := NewRulesAssistant()
	tr, err := r.Translate(context.Background(), "necesito agua", "es", "en")
	if err != nil {
		t.Fatalf("Translate error: %v", err)
	}
	if tr.Translated {
		t.Fatalf("offline translate must not claim Translated=true")
	}
	if tr.Text != "necesito agua" {
		t.Fatalf("offline translate must return original text, got %q", tr.Text)
	}
}

func TestRulesSummarizeDeterministic(t *testing.T) {
	r := NewRulesAssistant()
	items := []string{
		"Water available at the community center.",
		"Road on 5th street is blocked.",
		"Shelter 18 is now open.",
	}
	s1, err := r.Summarize(context.Background(), items)
	if err != nil {
		t.Fatalf("Summarize error: %v", err)
	}
	s2, _ := r.Summarize(context.Background(), items)
	if s1 != s2 {
		t.Fatalf("summarize not deterministic")
	}
	if s1 == "" {
		t.Fatalf("empty summary")
	}

	empty, _ := r.Summarize(context.Background(), nil)
	if empty == "" {
		t.Fatalf("expected a non-empty message for empty input")
	}
}

func TestRulesDedupFlagsDuplicateNotUnrelated(t *testing.T) {
	r := NewRulesAssistant()
	existing := []string{
		"Water available at community center on Main street",
		"Road obstruction reported near the highway bridge",
	}
	hits, err := r.Dedup(context.Background(),
		"community center on Main street has water available", existing)
	if err != nil {
		t.Fatalf("Dedup error: %v", err)
	}
	if len(hits) == 0 {
		t.Fatalf("expected the paraphrase to be flagged as a duplicate")
	}
	if hits[0].Index != 0 {
		t.Fatalf("expected index 0 (water report) as top hit, got %d", hits[0].Index)
	}

	none, _ := r.Dedup(context.Background(), "need blankets for three people tonight", existing)
	if len(none) != 0 {
		t.Fatalf("unrelated report should not be flagged as duplicate, got %+v", none)
	}
}
