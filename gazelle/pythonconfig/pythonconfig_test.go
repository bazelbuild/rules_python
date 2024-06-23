package pythonconfig

import (
	"testing"
)

func TestFormatThirdPartyDependency(t *testing.T) {
	type testInput struct {
		RepositoryName     string
		DistributionName   string
		LabelNormalization LabelNormalizationType
		LabelConvention    string
	}

	tests := map[string]struct {
		input testInput
		want  string
	}{
		"default / upper case": {
			input: testInput{
				DistributionName:   "DistWithUpperCase",
				RepositoryName:     "pip",
				LabelNormalization: DefaultLabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//distwithuppercase",
		},
		"default / dashes": {
			input: testInput{
				DistributionName:   "dist-with-dashes",
				RepositoryName:     "pip",
				LabelNormalization: DefaultLabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//dist_with_dashes",
		},
		"default / dots": {
			input: testInput{
				DistributionName:   "dist.with.dots",
				RepositoryName:     "pip",
				LabelNormalization: DefaultLabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//dist_with_dots",
		},
		"default / mixed": {
			input: testInput{
				DistributionName:   "To-be.sanitized",
				RepositoryName:     "pip",
				LabelNormalization: DefaultLabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//to_be_sanitized",
		},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			c := Config{
				labelNormalization: tc.input.LabelNormalization,
				labelConvention:    tc.input.LabelConvention,
			}
			gotLabel := c.FormatThirdPartyDependency(tc.input.RepositoryName, tc.input.DistributionName)
			got := gotLabel.String()
			if tc.want != got {
				t.Fatalf("expected %q, got %q", tc.want, got)
			}
		})
	}
}
