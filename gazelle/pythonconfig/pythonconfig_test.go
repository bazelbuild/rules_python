package pythonconfig

import (
	"strings"
	"testing"

	"github.com/bazelbuild/rules_python/gazelle/pythonconfig"
)

func TestDistributionSanitizingUpperCase(t *testing.T) {
	distname := "DistWithUpperCase"
	sanitized := pythonconfig.SanitizeDistribution(distname)

	if sanitized != strings.ToLower(distname) {
		t.Fatalf("Expected sanitized distribution name not to contain any upper case characters, got %s", sanitized)
	}
}

func TestDistributionStripsUnallowedCharacters(t *testing.T) {
	distname := "some-dist.with.bad-chars"
	sanitized := pythonconfig.SanitizeDistribution(distname)

	if strings.Contains(sanitized, "-") || strings.Contains(sanitized, "."){
		t.Fatalf("Expected sanitized distribution name not to contain any unallowed charecters ('-', '.'), got %s", sanitized)
	}
}
