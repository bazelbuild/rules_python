package manifest_test

import (
	"bytes"
	"log"
	"os"
	"reflect"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_python/gazelle/manifest"
)

var modulesMapping = manifest.ModulesMapping{
	"arrow":           "arrow",
	"arrow.__init__":  "arrow",
	"arrow.api":       "arrow",
	"arrow.arrow":     "arrow",
	"arrow.factory":   "arrow",
	"arrow.formatter": "arrow",
	"arrow.locales":   "arrow",
	"arrow.parser":    "arrow",
	"arrow.util":      "arrow",
}

const pipDepsRepositoryName = "test_repository_name"

func TestFile(t *testing.T) {
	t.Run("Encode", func(t *testing.T) {
		f := manifest.NewFile(&manifest.Manifest{
			ModulesMapping:        modulesMapping,
			PipDepsRepositoryName: pipDepsRepositoryName,
		})
		var b bytes.Buffer
		manifestGeneratorHashFile := strings.NewReader("")
		requirements, err := os.Open("testdata/requirements.txt")
		if err != nil {
			log.Println(err)
			t.FailNow()
		}
		defer requirements.Close()
		if err := f.Encode(&b, manifestGeneratorHashFile, requirements); err != nil {
			log.Println(err)
			t.FailNow()
		}
		expected, err := os.ReadFile("testdata/gazelle_python.yaml")
		if err != nil {
			log.Println(err)
			t.FailNow()
		}
		if !bytes.Equal(expected, b.Bytes()) {
			log.Printf("encoded manifest doesn't match expected output: %v\n", b.String())
			t.FailNow()
		}
	})
	t.Run("Decode", func(t *testing.T) {
		f := manifest.NewFile(&manifest.Manifest{})
		if err := f.Decode("testdata/gazelle_python.yaml"); err != nil {
			log.Println(err)
			t.FailNow()
		}
		if !reflect.DeepEqual(modulesMapping, f.Manifest.ModulesMapping) {
			log.Println("decoded modules_mapping doesn't match expected value")
			t.FailNow()
		}
		if f.Manifest.PipDepsRepositoryName != pipDepsRepositoryName {
			log.Println("decoded pip repository name doesn't match expected value")
			t.FailNow()
		}
	})
	t.Run("VerifyIntegrity", func(t *testing.T) {
		f := manifest.NewFile(&manifest.Manifest{})
		if err := f.Decode("testdata/gazelle_python.yaml"); err != nil {
			log.Println(err)
			t.FailNow()
		}
		manifestGeneratorHashFile := strings.NewReader("")
		requirements, err := os.Open("testdata/requirements.txt")
		if err != nil {
			log.Println(err)
			t.FailNow()
		}
		defer requirements.Close()
		valid, err := f.VerifyIntegrity(manifestGeneratorHashFile, requirements)
		if err != nil {
			log.Println(err)
			t.FailNow()
		}
		if !valid {
			log.Println("decoded manifest file is not valid")
			t.FailNow()
		}
	})
}
