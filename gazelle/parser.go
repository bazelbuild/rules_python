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
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"github.com/emirpasic/gods/sets/treeset"
	godsutils "github.com/emirpasic/gods/utils"
)

var (
	parserStdin  io.Writer
	parserStdout io.Reader
	parserMutex  sync.Mutex
)

func init() {
	parseScriptRunfile, err := bazel.Runfile("gazelle/parse")
	if err != nil {
		log.Printf("failed to initialize parser: %v\n", err)
		os.Exit(1)
	}

	ctx := context.Background()
	ctx, parserCancel := context.WithTimeout(ctx, time.Minute*5)
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
		defer parserCancel()
		if err := cmd.Wait(); err != nil {
			log.Printf("failed to wait for parser: %v\n", err)
			os.Exit(1)
		}
	}()
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

// parseAll parses all provided Python files by consecutively calling p.parse.
func (p *python3Parser) parseAll(pyFilepaths *treeset.Set) (*treeset.Set, error) {
	allModules := treeset.NewWith(moduleComparator)
	it := pyFilepaths.Iterator()
	for it.Next() {
		modules, err := p.parse(it.Value().(string))
		if err != nil {
			return nil, err
		}
		modulesIt := modules.Iterator()
		for modulesIt.Next() {
			allModules.Add(modulesIt.Value())
		}
	}
	return allModules, nil
}

// parse parses a Python file and returns the extracted modules from the import
// statements. An error is raised if communicating with the long-lived Python
// parser over stdin and stdout fails.
func (p *python3Parser) parse(pyFilepath string) (*treeset.Set, error) {
	parserMutex.Lock()
	defer parserMutex.Unlock()

	modules := treeset.NewWith(moduleComparator)

	relFilepath := filepath.Join(p.relPackagePath, pyFilepath)
	absFilepath := filepath.Join(p.repoRoot, relFilepath)
	fmt.Fprintln(parserStdin, absFilepath)
	reader := bufio.NewReader(parserStdout)
	data, err := reader.ReadBytes(0)
	if err != nil {
		return nil, fmt.Errorf("failed to parse %s: %w", pyFilepath, err)
	}
	data = data[:len(data)-1]
	var res parserResponse
	if err := json.Unmarshal(data, &res); err != nil {
		return nil, fmt.Errorf("failed to parse %s: %w", pyFilepath, err)
	}

	annotations := annotationsFromComments(res.Comments)

	for _, m := range res.Modules {
		// Check for ignored dependencies set via an annotation to the Python
		// module.
		if annotations.ignores(m.Name) {
			continue
		}

		// Check for ignored dependencies set via a Gazelle directive in a BUILD
		// file.
		if p.ignoresDependency(m.Name) {
			continue
		}

		m.Filepath = relFilepath

		modules.Add(m)
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
	Filepath string
}

// path returns the replaced dots with the os-specific path separator.
func (m *module) path() string {
	return filepath.Join(strings.Split(m.Name, ".")...)
}

// bazelPath returns the replaced dots with forward slashes.
func (m *module) bazelPath() string {
	return strings.ReplaceAll(m.Name, ".", "/")
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
func (c *comment) asAnnotation() *annotation {
	uncomment := strings.TrimLeft(string(*c), "# ")
	if !strings.HasPrefix(uncomment, annotationPrefix) {
		return nil
	}
	withoutPrefix := strings.TrimPrefix(uncomment, annotationPrefix)
	annotationParts := strings.SplitN(withoutPrefix, " ", 2)
	return &annotation{
		kind:  annotationKind(annotationParts[0]),
		value: annotationParts[1],
	}
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
func annotationsFromComments(comments []comment) *annotations {
	ignore := make(map[string]struct{})
	for _, comment := range comments {
		annotation := comment.asAnnotation()
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
	}
}

// ignored returns true if the given module was ignored via the ignore
// annotation.
func (a *annotations) ignores(module string) bool {
	_, ignores := a.ignore[module]
	return ignores
}
