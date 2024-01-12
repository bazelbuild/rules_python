package pythonconfig

import (
	"testing"
)

func TestDistributionSanitizing(t *testing.T) {
	tests := map[string]struct {
		input string
		want  string
	}{
		"upper case": {input: "DistWithUpperCase", want: "distwithuppercase"},
		"dashes":     {input: "dist-with-dashes", want: "dist_with_dashes"},
		"dots":       {input: "dist.with.dots", want: "dist_with_dots"},
		"mixed":      {input: "To-be.sanitized", want: "to_be_sanitized"},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			got := SanitizeDistribution(tc.input)
			if tc.want != got {
				t.Fatalf("expected %q, got %q", tc.want, got)
			}
		})
	}
}
