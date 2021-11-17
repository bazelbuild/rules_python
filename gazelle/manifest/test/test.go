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
	"path/filepath"

	"github.com/bazelbuild/rules_python/gazelle/manifest"
)

func main() {
	var requirementsPath string
	var manifestPath string
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

	valid, err := manifestFile.VerifyIntegrity(requirementsPath)
	if err != nil {
		log.Fatalf("ERROR: %v\n", err)
	}
	if !valid {
		manifestRealpath, err := filepath.EvalSymlinks(manifestPath)
		if err != nil {
			log.Fatalf("ERROR: %v\n", err)
		}
		log.Fatalf(
			"ERROR: %q is out-of-date, follow the intructions on this file for updating.\n",
			manifestRealpath)
	}
}