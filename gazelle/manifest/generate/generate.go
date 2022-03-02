/*
generate.go is a program that generates the Gazelle YAML manifest.

The Gazelle manifest is a file that contains extra information required when
generating the Bazel BUILD files.
*/
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/bazelbuild/rules_python/gazelle/manifest"
)

func init() {
	if os.Getenv("BUILD_WORKSPACE_DIRECTORY") == "" {
		log.Fatalln("ERROR: this program must run under Bazel")
	}
}

func main() {
	var requirementsPath string
	var pipRepositoryName string
	var pipRepositoryIncremental bool
	var modulesMappingPath string
	var outputPath string
	var updateTarget string
	flag.StringVar(
		&requirementsPath,
		"requirements",
		"",
		"The requirements.txt file.")
	flag.StringVar(
		&pipRepositoryName,
		"pip-repository-name",
		"",
		"The name of the pip_install or pip_repository target.")
	flag.BoolVar(
		&pipRepositoryIncremental,
		"pip-repository-incremental",
		false,
		"The value for the incremental option in pip_repository.")
	flag.StringVar(
		&modulesMappingPath,
		"modules-mapping",
		"",
		"The modules_mapping.json file.")
	flag.StringVar(
		&outputPath,
		"output",
		"",
		"The output YAML manifest file.")
	flag.StringVar(
		&updateTarget,
		"update-target",
		"",
		"The Bazel target to update the YAML manifest file.")
	flag.Parse()

	if requirementsPath == "" {
		log.Fatalln("ERROR: --requirements must be set")
	}

	if modulesMappingPath == "" {
		log.Fatalln("ERROR: --modules-mapping must be set")
	}

	if outputPath == "" {
		log.Fatalln("ERROR: --output must be set")
	}

	if updateTarget == "" {
		log.Fatalln("ERROR: --update-target must be set")
	}

	modulesMapping, err := unmarshalJSON(modulesMappingPath)
	if err != nil {
		log.Fatalf("ERROR: %v\n", err)
	}

	header := generateHeader(updateTarget)

	manifestFile := manifest.NewFile(&manifest.Manifest{
		ModulesMapping: modulesMapping,
		PipRepository: &manifest.PipRepository{
			Name:        pipRepositoryName,
			Incremental: pipRepositoryIncremental,
		},
	})
	if err := writeOutput(outputPath, header, manifestFile, requirementsPath); err != nil {
		log.Fatalf("ERROR: %v\n", err)
	}
}

// unmarshalJSON returns the parsed mapping from the given JSON file path.
func unmarshalJSON(jsonPath string) (map[string]string, error) {
	file, err := os.Open(jsonPath)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON file: %w", err)
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	output := make(map[string]string)
	if err := decoder.Decode(&output); err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON file: %w", err)
	}

	return output, nil
}

// generateHeader generates the YAML header human-readable comment.
func generateHeader(updateTarget string) string {
	var header strings.Builder
	header.WriteString("# GENERATED FILE - DO NOT EDIT!\n")
	header.WriteString("#\n")
	header.WriteString("# To update this file, run:\n")
	header.WriteString(fmt.Sprintf("#   bazel run %s\n", updateTarget))
	return header.String()
}

// writeOutput writes to the final file the header and manifest structure.
func writeOutput(
	outputPath string,
	header string,
	manifestFile *manifest.File,
	requirementsPath string,
) error {
	stat, err := os.Stat(outputPath)
	if err != nil {
		return fmt.Errorf("failed to write output: %w", err)
	}

	outputFile, err := os.OpenFile(outputPath, os.O_WRONLY|os.O_TRUNC, stat.Mode())
	if err != nil {
		return fmt.Errorf("failed to write output: %w", err)
	}
	defer outputFile.Close()

	if _, err := fmt.Fprintf(outputFile, "%s\n", header); err != nil {
		return fmt.Errorf("failed to write output: %w", err)
	}

	if err := manifestFile.Encode(outputFile, requirementsPath); err != nil {
		return fmt.Errorf("failed to write output: %w", err)
	}

	return nil
}
