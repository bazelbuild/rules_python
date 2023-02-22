package pythonconfig

import (
	"reflect"
	"testing"

	"github.com/bazelbuild/rules_python/gazelle/pythonconfig"
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
			got := pythonconfig.SanitizeDistribution(tc.input)
			if !reflect.DeepEqual(tc.want, got) {
				t.Fatalf("expected %#v, got %#v", tc.want, got)
			}
		})
	}
}
