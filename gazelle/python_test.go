/* Copyright 2020 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// This test file was first seen on:
// https://github.com/bazelbuild/bazel-skylib/blob/f80bc733d4b9f83d427ce3442be2e07427b2cc8d/gazelle/bzl/BUILD.
// It was modified for the needs of this extension.

package python_test

import (
	"bytes"
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/bazelbuild/bazel-gazelle/testtools"
	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"github.com/ghodss/yaml"
)

const (
	extensionDir      = "gazelle/"
	testDataPath      = extensionDir + "testdata/"
	gazelleBinaryName = "gazelle_python_binary"
)

var gazellePath = mustFindGazelle()

func TestGazelleBinary(t *testing.T) {
	tests := map[string][]bazel.RunfileEntry{}

	runfiles, err := bazel.ListRunfiles()
	if err != nil {
		t.Fatalf("bazel.ListRunfiles() error: %v", err)
	}
	for _, f := range runfiles {
		if strings.HasPrefix(f.ShortPath, testDataPath) {
			relativePath := strings.TrimPrefix(f.ShortPath, testDataPath)
			parts := strings.SplitN(relativePath, "/", 2)
			if len(parts) < 2 {
				// This file is not a part of a testcase since it must be in a dir that
				// is the test case and then have a path inside of that.
				continue
			}

			tests[parts[0]] = append(tests[parts[0]], f)
		}
	}
	if len(tests) == 0 {
		t.Fatal("no tests found")
	}

	for testName, files := range tests {
		testPath(t, testName, files)
	}
}

func testPath(t *testing.T, name string, files []bazel.RunfileEntry) {
	t.Run(name, func(t *testing.T) {
		t.Parallel()

		config := newTestCase(t, name, files)
		config.createFiles(t, config.inputs)

		got := config.RunCommand(t, gazellePath, "-build_file_name=BUILD,BUILD.bazel")

		if config.Expect.ExitCode != got.ExitCode {
			t.Errorf("expected gazelle exit code: %d\ngot: %d",
				config.Expect.ExitCode, got.ExitCode,
			)
		}

		if strings.TrimSpace(config.Expect.Stdout) != got.Stdout {
			t.Errorf("expected gazelle stdout: %s\ngot: %s",
				config.Expect.Stdout, got.Stdout,
			)
		}
		if strings.TrimSpace(config.Expect.Stderr) != got.Stderr {
			t.Errorf("expected gazelle stderr: %s\ngot: %s",
				config.Expect.Stderr, got.Stderr,
			)
		}

		if t.Failed() {
			return
		}

		testtools.CheckFiles(t, config.dir, config.goldens)
	})
}

func mustFindGazelle() string {
	gazellePath, ok := bazel.FindBinary(extensionDir, gazelleBinaryName)
	if !ok {
		panic("could not find gazelle binary")
	}
	return gazellePath
}

type testCase struct {
	name string
	dir string
	workspaceRoot string
	timeout time.Duration

	inputs, goldens []testtools.FileSpec

	Expect CommandResult `json:"expect"`
}

type CommandResult struct {
	ExitCode int    `json:"exit_code"`
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
}

func newTestCase(t testing.TB, name string, files []bazel.RunfileEntry) *testCase {
	var (
		inputs, goldens []testtools.FileSpec
		config *testCase
	)

	for _, f := range files {
		info, err := os.Stat(f.Path)
		if err != nil {
			t.Fatalf("stat %q: %v", f.Path, err)
		}

		if info.IsDir() {
			continue
		}

		content, err := os.ReadFile(f.Path)
		if err != nil {
			t.Fatalf("read %q: %w", f.Path, err)
		}

		shortPath, err := filepath.Rel(testDataPath + name, f.ShortPath)
		if err != nil {
			t.Fatalf("relpath: %w", err)
		}


		if strings.HasSuffix(shortPath, ".in") {
			inputs = append(inputs, testtools.FileSpec{
				Path:    filepath.Join(name, strings.TrimSuffix(shortPath, ".in")),
				Content: string(content),
			})
			continue
		}

		if strings.HasSuffix(shortPath, ".out") {
			goldens = append(goldens, testtools.FileSpec{
				Path:    filepath.Join(name, strings.TrimSuffix(shortPath, ".out")),
				Content: string(content),
			})
			continue
		}

		inputs = append(inputs, testtools.FileSpec{
			Path:    filepath.Join(name, shortPath),
			Content: string(content),
		})
		goldens = append(goldens, testtools.FileSpec{
			Path:    filepath.Join(name, shortPath),
			Content: string(content),
		})

		if filepath.Base(shortPath) != "test.yaml" {
			continue
		}

		if config != nil {
			t.Fatal("only 1 'test.yaml' is supported")
		}

		config = &testCase{
			name: name,
			timeout: 2 * time.Second,
		}
		if err := yaml.Unmarshal(content, config); err != nil {
			t.Fatal(err)
		}
	}

	config.inputs = inputs
	config.goldens = goldens

	return config
}

func (tc *testCase) createFiles(t *testing.T, files []testtools.FileSpec) {
	dir, cleanup := testtools.CreateFiles(t, files)
	t.Cleanup(cleanup)
	t.Cleanup(func() {
		if t.Failed() {
			filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
				if err != nil {
					return err
				}

				t.Logf("%q exists", strings.TrimPrefix(path, dir))
				return nil
			})
		}
	})

	tc.dir = dir
	tc.workspaceRoot = filepath.Join(dir, tc.name)
}

func (tc *testCase) context(t *testing.T) context.Context {
	ctx := context.Background()

	deadline, ok := t.Deadline()
	if !ok {
		// no timeout set on the CLI, let's respect this, because there may be
		// a debugger or something present.
		return ctx
	}

	ctx, cancel := context.WithDeadline(ctx, deadline)
	t.Cleanup(cancel)

	ctx, cancel = context.WithTimeout(ctx, tc.timeout)
	t.Cleanup(cancel)
	return ctx
}

func (tc *testCase) RunCommand(t *testing.T, bin string, args ...string) CommandResult {
	ctx := tc.context(t)
	cmd := exec.CommandContext(ctx, bin, args...)

	var stdout, stderr bytes.Buffer

	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	cmd.Dir = tc.workspaceRoot

	if err := cmd.Run(); err != nil {
		var e *exec.ExitError
		if !errors.As(err, &e) {
			t.Fatal(err)
		}
	}

	return CommandResult{
		ExitCode: cmd.ProcessState.ExitCode(),
		Stdout: strings.TrimSpace(stdout.String()),
		Stderr: strings.TrimSpace(stderr.String()),
	}
}
