// Copyright 2023 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package python

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"
	"sync"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"github.com/emirpasic/gods/sets/treeset"
	godsutils "github.com/emirpasic/gods/utils"
)

var (
	parserStdin  io.WriteCloser
	parserStdout io.Reader
	parserMutex  sync.Mutex
)

func startParserProcess(ctx context.Context) {
	parseScriptRunfile, err := bazel.Runfile("python/parse")
	if err != nil {
		log.Printf("failed to initialize parser: %v\n", err)
		os.Exit(1)
	}

	cmd := exec.CommandContext(ctx, parseScriptRunfile)

	cmd.Stderr = os.Stderr

	stdin, err := cmd.StdinPipe()
	if err != nil {
		log.Printf("failed to initialize parser: %v\n", err)
		os.Exit(1)
	}
	parserStdin = stdin

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Printf("failed to initialize parser: %v\n", err)
		os.Exit(1)
	}
	parserStdout = stdout

	if err := cmd.Start(); err != nil {
		log.Printf("failed to initialize parser: %v\n", err)
		os.Exit(1)
	}

	go func() {
		if err := cmd.Wait(); err != nil {
			log.Printf("failed to wait for parser: %v\n", err)
			os.Exit(1)
		}
	}()
}

func shutdownParserProcess() {
	if err := parserStdin.Close(); err != nil {
		fmt.Fprintf(os.Stderr, "error closing parser: %v", err)
	}
}

// python3Parser implements a parser for Python files that extracts the modules
// as seen in the import statements.
type python3Parser struct {
	// The value of language.GenerateArgs.Config.RepoRoot.
	repoRoot string
	// The value of language.GenerateArgs.Rel.
	relPackagePath string
	// The function that determines if a dependency is ignored from a Gazelle
	// directive. It's the signature of pythonconfig.Config.IgnoresDependency.
	ignoresDependency func(dep string) bool
}

// newPython3Parser constructs a new python3Parser.
func newPython3Parser(
	repoRoot string,
	relPackagePath string,
	ignoresDependency func(dep string) bool,
) *python3Parser {
	return &python3Parser{
		repoRoot:          repoRoot,
		relPackagePath:    relPackagePath,
		ignoresDependency: ignoresDependency,
	}
}

// parseSingle parses a single Python file and returns the extracted modules
// from the import statements as well as the parsed comments.
func (p *python3Parser) parseSingle(pyFilename string) (*treeset.Set, error) {
	pyFilenames := treeset.NewWith(godsutils.StringComparator)
	pyFilenames.Add(pyFilename)
	return p.parse(pyFilenames)
}

// parse parses multiple Python files and returns the extracted modules from
// the import statements as well as the parsed comments.
func (p *python3Parser) parse(pyFilenames *treeset.Set) (*treeset.Set, error) {
	parserMutex.Lock()
	defer parserMutex.Unlock()

	modules := treeset.NewWith(moduleComparator)

	req := map[string]interface{}{
		"repo_root":        p.repoRoot,
		"rel_package_path": p.relPackagePath,
		"filenames":        pyFilenames.Values(),
	}
	encoder := json.NewEncoder(parserStdin)
	if err := encoder.Encode(&req); err != nil {
		return nil, fmt.Errorf("failed to parse: %w", err)
	}

	reader := bufio.NewReader(parserStdout)
	data, err := reader.ReadBytes(0)
	if err != nil {
		return nil, fmt.Errorf("failed to parse: %w", err)
	}
	data = data[:len(data)-1]
	var allRes []parserResponse
	if err := json.Unmarshal(data, &allRes); err != nil {
		return nil, fmt.Errorf("failed to parse: %w", err)
	}

	for _, res := range allRes {
		annotations, err := annotationsFromComments(res.Comments)
		if err != nil {
			return nil, fmt.Errorf("failed to parse annotations: %w", err)
		}

		for _, m := range res.Modules {
			// Check for ignored dependencies set via an annotation to the Python
			// module.
			if annotations.ignores(m.Name) || annotations.ignores(m.From) {
				continue
			}

			// Check for ignored dependencies set via a Gazelle directive in a BUILD
			// file.
			if p.ignoresDependency(m.Name) || p.ignoresDependency(m.From) {
				continue
			}

			modules.Add(m)
		}
	}

	return modules, nil
}

// parserResponse represents a response returned by the parser.py for a given
// parsed Python module.
type parserResponse struct {
	// The modules depended by the parsed module.
	Modules []module `json:"modules"`
	// The comments contained in the parsed module. This contains the
	// annotations as they are comments in the Python module.
	Comments []comment `json:"comments"`
}

// module represents a fully-qualified, dot-separated, Python module as seen on
// the import statement, alongside the line number where it happened.
type module struct {
	// The fully-qualified, dot-separated, Python module name as seen on import
	// statements.
	Name string `json:"name"`
	// The line number where the import happened.
	LineNumber uint32 `json:"lineno"`
	// The path to the module file relative to the Bazel workspace root.
	Filepath string `json:"filepath"`
	// If this was a from import, e.g. from foo import bar, From indicates the module
	// from which it is imported.
	From string `json:"from"`
}

// moduleComparator compares modules by name.
func moduleComparator(a, b interface{}) int {
	return godsutils.StringComparator(a.(module).Name, b.(module).Name)
}

// annotationKind represents Gazelle annotation kinds.
type annotationKind string

const (
	// The Gazelle annotation prefix.
	annotationPrefix string = "gazelle:"
	// The ignore annotation kind. E.g. '# gazelle:ignore <module_name>'.
	annotationKindIgnore annotationKind = "ignore"
)

// comment represents a Python comment.
type comment string

// asAnnotation returns an annotation object if the comment has the
// annotationPrefix.
func (c *comment) asAnnotation() (*annotation, error) {
	uncomment := strings.TrimLeft(string(*c), "# ")
	if !strings.HasPrefix(uncomment, annotationPrefix) {
		return nil, nil
	}
	withoutPrefix := strings.TrimPrefix(uncomment, annotationPrefix)
	annotationParts := strings.SplitN(withoutPrefix, " ", 2)
	if len(annotationParts) < 2 {
		return nil, fmt.Errorf("`%s` requires a value", *c)
	}
	return &annotation{
		kind:  annotationKind(annotationParts[0]),
		value: annotationParts[1],
	}, nil
}

// annotation represents a single Gazelle annotation parsed from a Python
// comment.
type annotation struct {
	kind  annotationKind
	value string
}

// annotations represent the collection of all Gazelle annotations parsed out of
// the comments of a Python module.
type annotations struct {
	// The parsed modules to be ignored by Gazelle.
	ignore map[string]struct{}
}

// annotationsFromComments returns all the annotations parsed out of the
// comments of a Python module.
func annotationsFromComments(comments []comment) (*annotations, error) {
	ignore := make(map[string]struct{})
	for _, comment := range comments {
		annotation, err := comment.asAnnotation()
		if err != nil {
			return nil, err
		}
		if annotation != nil {
			if annotation.kind == annotationKindIgnore {
				modules := strings.Split(annotation.value, ",")
				for _, m := range modules {
					if m == "" {
						continue
					}
					m = strings.TrimSpace(m)
					ignore[m] = struct{}{}
				}
			}
		}
	}
	return &annotations{
		ignore: ignore,
	}, nil
}

// ignored returns true if the given module was ignored via the ignore
// annotation.
func (a *annotations) ignores(module string) bool {
	_, ignores := a.ignore[module]
	return ignores
}
