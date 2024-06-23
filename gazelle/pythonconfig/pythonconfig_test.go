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
		"default / upper case / custom prefix & suffix": {
			input: testInput{
				DistributionName:   "DistWithUpperCase",
				RepositoryName:     "pip",
				LabelNormalization: DefaultLabelNormalizationType,
				LabelConvention:    "pReFiX-$distribution_name$-sUfFiX",
			},
			want: "@pip//prefix_distwithuppercase_suffix",
		},
		"noop normalization / mixed": {
			input: testInput{
				DistributionName:   "not-TO-be.sanitized",
				RepositoryName:     "pip",
				LabelNormalization: NoLabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//not-TO-be.sanitized",
		},
		"noop normalization / mixed / custom prefix & suffix": {
			input: testInput{
				DistributionName:   "not-TO-be.sanitized",
				RepositoryName:     "pip",
				LabelNormalization: NoLabelNormalizationType,
				LabelConvention:    "pre___$distribution_name$___fix",
			},
			want: "@pip//pre___not-TO-be.sanitized___fix",
		},
		"pep503 / upper case": {
			input: testInput{
				DistributionName:   "DistWithUpperCase",
				RepositoryName:     "pip",
				LabelNormalization: Pep503LabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//distwithuppercase",
		},
		"pep503 / underscores": {
			input: testInput{
				DistributionName:   "dist_with_underscores",
				RepositoryName:     "pip",
				LabelNormalization: Pep503LabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//dist-with-underscores",
		},
		"pep503 / dots": {
			input: testInput{
				DistributionName:   "dist.with.dots",
				RepositoryName:     "pip",
				LabelNormalization: Pep503LabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//dist-with-dots",
		},
		"pep503 / mixed": {
			input: testInput{
				DistributionName:   "To-be.sanitized",
				RepositoryName:     "pip",
				LabelNormalization: Pep503LabelNormalizationType,
				LabelConvention:    DefaultLabelConvention,
			},
			want: "@pip//to-be-sanitized",
		},
		"pep503 / underscores / custom prefix & suffix": {
			input: testInput{
				DistributionName:   "dist_with_underscores",
				RepositoryName:     "pip",
				LabelNormalization: Pep503LabelNormalizationType,
				LabelConvention:    "pre___$distribution_name$___fix",
			},
			want: "@pip//pre-dist-with-underscores-fix",
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
