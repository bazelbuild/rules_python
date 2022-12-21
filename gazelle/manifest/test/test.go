/*
test.go is a program that asserts the Gazelle YAML manifest is up-to-date in
regards to the requirements.txt.

It re-hashes the requirements.txt and compares it to the recorded one in the
existing generated Gazelle manifest.
*/
package main

import (
	"flag"
	"log"
	"os"
	"path/filepath"

	"github.com/bazelbuild/rules_python/gazelle/manifest"
)

func main() {
	var manifestGeneratorHashPath string
	var requirementsPath string
	var manifestPath string
	flag.StringVar(
		&manifestGeneratorHashPath,
		"manifest-generator-hash",
		"",
		"The file containing the hash for the source code of the manifest generator."+
			"This is important to force manifest updates when the generator logic changes.")
	flag.StringVar(
		&requirementsPath,
		"requirements",
		"",
		"The requirements.txt file.")
	flag.StringVar(
		&manifestPath,
		"manifest",
		"",
		"The manifest YAML file.")
	flag.Parse()

	if requirementsPath == "" {
		log.Fatalln("ERROR: --requirements must be set")
	}

	if manifestPath == "" {
		log.Fatalln("ERROR: --manifest must be set")
	}

	manifestFile := new(manifest.File)
	if err := manifestFile.Decode(manifestPath); err != nil {
		log.Fatalf("ERROR: %v\n", err)
	}

	if manifestFile.Integrity == "" {
		log.Fatalln("ERROR: failed to find the Gazelle manifest file integrity")
	}

	manifestGeneratorHash, err := os.Open(manifestGeneratorHashPath)
	if err != nil {
		log.Fatalf("ERROR: %v\n", err)
	}
	defer manifestGeneratorHash.Close()

	requirements, err := os.Open(requirementsPath)
	if err != nil {
		log.Fatalf("ERROR: %v\n", err)
	}
	defer requirements.Close()

	valid, err := manifestFile.VerifyIntegrity(manifestGeneratorHash, requirements)
	if err != nil {
		log.Fatalf("ERROR: %v\n", err)
	}
	if !valid {
		manifestRealpath, err := filepath.EvalSymlinks(manifestPath)
		if err != nil {
			log.Fatalf("ERROR: %v\n", err)
		}
		log.Fatalf(
			"ERROR: %q is out-of-date. Follow the update instructions in that file to resolve this.\n",
			manifestRealpath)
	}
}
