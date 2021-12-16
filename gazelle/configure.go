package python

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/config"
	"github.com/bazelbuild/bazel-gazelle/rule"

	"github.com/bazelbuild/rules_python/gazelle/manifest"
	"github.com/bazelbuild/rules_python/gazelle/pythonconfig"
)

// Configurer satisfies the config.Configurer interface. It's the
// language-specific configuration extension.
type Configurer struct{}

// RegisterFlags registers command-line flags used by the extension. This
// method is called once with the root configuration when Gazelle
// starts. RegisterFlags may set an initial values in Config.Exts. When flags
// are set, they should modify these values.
func (py *Configurer) RegisterFlags(fs *flag.FlagSet, cmd string, c *config.Config) {}

// CheckFlags validates the configuration after command line flags are parsed.
// This is called once with the root configuration when Gazelle starts.
// CheckFlags may set default values in flags or make implied changes.
func (py *Configurer) CheckFlags(fs *flag.FlagSet, c *config.Config) error {
	return nil
}

// KnownDirectives returns a list of directive keys that this Configurer can
// interpret. Gazelle prints errors for directives that are not recoginized by
// any Configurer.
func (py *Configurer) KnownDirectives() []string {
	return []string{
		pythonconfig.PythonExtensionDirective,
		pythonconfig.PythonRootDirective,
		pythonconfig.PythonManifestFileNameDirective,
		pythonconfig.IgnoreFilesDirective,
		pythonconfig.IgnoreDependenciesDirective,
		pythonconfig.ValidateImportStatementsDirective,
		pythonconfig.GenerationMode,
		pythonconfig.LibraryNamingConvention,
		pythonconfig.BinaryNamingConvention,
		pythonconfig.TestNamingConvention,
	}
}

// Configure modifies the configuration using directives and other information
// extracted from a build file. Configure is called in each directory.
//
// c is the configuration for the current directory. It starts out as a copy
// of the configuration for the parent directory.
//
// rel is the slash-separated relative path from the repository root to
// the current directory. It is "" for the root directory itself.
//
// f is the build file for the current directory or nil if there is no
// existing build file.
func (py *Configurer) Configure(c *config.Config, rel string, f *rule.File) {
	// Create the root config.
	if _, exists := c.Exts[languageName]; !exists {
		rootConfig := pythonconfig.New(c.RepoRoot, "")
		c.Exts[languageName] = pythonconfig.Configs{"": rootConfig}
	}

	configs := c.Exts[languageName].(pythonconfig.Configs)

	config, exists := configs[rel]
	if !exists {
		parent := configs.ParentForPackage(rel)
		config = parent.NewChild()
		configs[rel] = config
	}

	if f == nil {
		return
	}

	gazelleManifestFilename := "gazelle_python.yaml"

	for _, d := range f.Directives {
		switch d.Key {
		case "exclude":
			// We record the exclude directive for coarse-grained packages
			// since we do manual tree traversal in this mode.
			config.AddExcludedPattern(strings.TrimSpace(d.Value))
		case pythonconfig.PythonExtensionDirective:
			switch d.Value {
			case "enabled":
				config.SetExtensionEnabled(true)
			case "disabled":
				config.SetExtensionEnabled(false)
			default:
				err := fmt.Errorf("invalid value for directive %q: %s: possible values are enabled/disabled",
					pythonconfig.PythonExtensionDirective, d.Value)
				log.Fatal(err)
			}
		case pythonconfig.PythonRootDirective:
			config.SetPythonProjectRoot(rel)
		case pythonconfig.PythonManifestFileNameDirective:
			gazelleManifestFilename = strings.TrimSpace(d.Value)
		case pythonconfig.IgnoreFilesDirective:
			for _, ignoreFile := range strings.Split(d.Value, ",") {
				config.AddIgnoreFile(ignoreFile)
			}
		case pythonconfig.IgnoreDependenciesDirective:
			for _, ignoreDependency := range strings.Split(d.Value, ",") {
				config.AddIgnoreDependency(ignoreDependency)
			}
		case pythonconfig.ValidateImportStatementsDirective:
			v, err := strconv.ParseBool(strings.TrimSpace(d.Value))
			if err != nil {
				log.Fatal(err)
			}
			config.SetValidateImportStatements(v)
		case pythonconfig.GenerationMode:
			switch pythonconfig.GenerationModeType(strings.TrimSpace(d.Value)) {
			case pythonconfig.GenerationModePackage:
				config.SetCoarseGrainedGeneration(false)
			case pythonconfig.GenerationModeProject:
				config.SetCoarseGrainedGeneration(true)
			default:
				err := fmt.Errorf("invalid value for directive %q: %s",
					pythonconfig.GenerationMode, d.Value)
				log.Fatal(err)
			}
		case pythonconfig.LibraryNamingConvention:
			config.SetLibraryNamingConvention(strings.TrimSpace(d.Value))
		case pythonconfig.BinaryNamingConvention:
			config.SetBinaryNamingConvention(strings.TrimSpace(d.Value))
		case pythonconfig.TestNamingConvention:
			config.SetTestNamingConvention(strings.TrimSpace(d.Value))
		}
	}

	gazelleManifestPath := filepath.Join(c.RepoRoot, rel, gazelleManifestFilename)
	gazelleManifest, err := py.loadGazelleManifest(gazelleManifestPath)
	if err != nil {
		log.Fatal(err)
	}
	if gazelleManifest != nil {
		config.SetGazelleManifest(gazelleManifest)
	}
}

func (py *Configurer) loadGazelleManifest(gazelleManifestPath string) (*manifest.Manifest, error) {
	if _, err := os.Stat(gazelleManifestPath); err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to load Gazelle manifest at %q: %w", gazelleManifestPath, err)
	}
	manifestFile := new(manifest.File)
	if err := manifestFile.Decode(gazelleManifestPath); err != nil {
		return nil, fmt.Errorf("failed to load Gazelle manifest at %q: %w", gazelleManifestPath, err)
	}
	return manifestFile.Manifest, nil
}
