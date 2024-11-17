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
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-python/gpython/ast"
	"github.com/go-python/gpython/parser"
	"github.com/go-python/gpython/py"
)

type ParserOutput struct {
	FileName string
	Modules  []module
	Comments []comment
	HasMain  bool
}

type FileParser struct {
	code        []byte
	relFilepath string
	output      ParserOutput
}

func NewFileParser() *FileParser {
	return &FileParser{}
}

func (p *FileParser) parseMain(m *ast.Module) {
	for _, stmt := range m.Body {
		ifStmt, ok := stmt.(*ast.If)
		if !ok {
			continue
		}
		comp, ok := ifStmt.Test.(*ast.Compare)
		if !ok {
			return
		}
		if comp.Ops[0] != ast.Eq {
			return
		}
		var foundName, foundMain bool
		visit := func(expr ast.Ast) {
			switch actual := expr.(type) {
			case *ast.Name:
				foundName = true
			case *ast.Str:
				if actual.S == "__main__" {
					foundMain = true
				}
			}
		}
		visit(comp.Left)
		visit(comp.Comparators[0])
		if foundMain && foundName {
			p.output.HasMain = true
			break
		}
	}
}

func (p *FileParser) parseImportStatements(node ast.Ast, relPath string) {
	switch n := node.(type) {
	case *ast.Import:
		for _, name := range n.Names {
			nameString := string(name.Name)
			if strings.HasPrefix(nameString, ".") {
				continue
			}
			p.output.Modules = append(p.output.Modules, module{
				Name:       nameString,
				LineNumber: uint32(n.GetLineno()),
				Filepath:   relPath,
			})
		}
	case *ast.ImportFrom:
		for _, name := range n.Names {
			if n.Level > 0 {
				// from . import abc or from .. import foo
				continue
			}
			moduleString := string(n.Module)
			p.output.Modules = append(p.output.Modules, module{
				Name:       moduleString + "." + string(name.Name),
				LineNumber: uint32(n.GetLineno()),
				Filepath:   relPath,
				From:       moduleString,
			})
		}
	}
}

func (p *FileParser) parseComments(ctx context.Context, input io.Reader) error {
	scanner := bufio.NewScanner(input)
	for scanner.Scan() {
		if ctx.Err() != nil {
			break
		}
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "#") {
			p.output.Comments = append(p.output.Comments, comment(line))
		}
	}
	return nil
}

func (p *FileParser) ParseFile(ctx context.Context, repoRoot, relPackagePath, filename string) (*ParserOutput, error) {
	relPath := filepath.Join(relPackagePath, filename)
	absPath := filepath.Join(repoRoot, relPath)
	fileObj, err := os.Open(absPath)
	if err != nil {
		return nil, fmt.Errorf("opening %q: %w", relPath, err)
	}
	defer fileObj.Close()
	if err := p.parseAST(ctx, fileObj, relPath); err != nil {
		return nil, fmt.Errorf("parsing AST in %q: %w", relPath, err)
	}
	// comments are not included in the AST. Reading the file again to get comments
	if _, err := fileObj.Seek(0, 0); err != nil {
		return nil, fmt.Errorf("rewinding %q: %w", relPath, err)
	}
	if err := p.parseComments(ctx, fileObj); err != nil {
		return nil, fmt.Errorf("parsing comments in %q: %w", filename, err)
	}
	p.output.FileName = filename
	return &p.output, nil
}

func (p *FileParser) parseAST(ctx context.Context, input io.Reader, relPath string) error {
	mod, err := parser.Parse(input, relPath, py.ExecMode)
	if err != nil {
		return fmt.Errorf("parsing %q: %w", relPath, err)
	}
	ast.Walk(mod, func(node ast.Ast) bool {
		switch typedNode := node.(type) {
		case *ast.Import, *ast.ImportFrom:
			p.parseImportStatements(node, relPath)
		case *ast.Module:
			p.parseMain(typedNode)
		}
		return ctx.Err() == nil
	})
	return nil
}
