package main

import (
	"bytes"
	"strings"
	"testing"

	cp "github.com/metacubex/mihomo/constant/provider"
	rp "github.com/metacubex/mihomo/rules/provider"
)

// The whole rule-set viewer rests on one assumption: the core we already link
// against can turn a binary MRS set back into readable lines. ConvertToMrs is
// named for the other direction, and only takes the "export to TextRule" branch
// when the *source* format is MrsRule -- easy to get backwards, and impossible
// to notice from the app, where a wrong call just shows plausible-looking
// garbage. This pins the round trip.
func TestMrsDecodesBackToText(t *testing.T) {
	const payload = "payload:\n  - '+.example.com'\n  - 'vk.com'\n  - '+.github.io'\n"

	var encoded bytes.Buffer
	if err := rp.ConvertToMrs([]byte(payload), cp.Domain, cp.YamlRule, &encoded); err != nil {
		t.Fatalf("encode to mrs: %v", err)
	}
	if encoded.Len() == 0 {
		t.Fatal("encoder produced nothing")
	}

	var decoded bytes.Buffer
	if err := rp.ConvertToMrs(encoded.Bytes(), cp.Domain, cp.MrsRule, &decoded); err != nil {
		t.Fatalf("decode from mrs: %v", err)
	}

	text := decoded.String()
	for _, want := range []string{"example.com", "vk.com", "github.io"} {
		if !strings.Contains(text, want) {
			t.Errorf("decoded set is missing %q; got:\n%s", want, text)
		}
	}
	// Binary would still "contain" nothing readable -- make sure we got lines.
	if lines := strings.Count(strings.TrimSpace(text), "\n") + 1; lines != 3 {
		t.Errorf("expected 3 lines, got %d:\n%s", lines, text)
	}
}

// A classical .list or an inline payload is already text; the decode is
// expected to fail there and the caller falls back to the raw bytes.
func TestTextRuleSetIsNotMistakenForMrs(t *testing.T) {
	raw := []byte("DOMAIN-SUFFIX,anydesk.com\nDOMAIN-SUFFIX,rustdesk.com\n")

	var decoded bytes.Buffer
	if err := rp.ConvertToMrs(raw, cp.Classical, cp.MrsRule, &decoded); err == nil {
		t.Fatal("expected a text list to fail the mrs decode, so the caller falls back")
	}
}
