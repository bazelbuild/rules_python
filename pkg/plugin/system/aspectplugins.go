/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package system

import (
	"fmt"
	"io/fs"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"

	yaml "gopkg.in/yaml.v2"
)

const (
	workspaceFilename     = "WORKSPACE"
	aspectpluginsFilename = ".aspectplugins"
)

// AspectPlugin represents a plugin entry in the plugins file.
type AspectPlugin struct {
	Name       string                 `yaml:"name"`
	From       string                 `yaml:"from"`
	LogLevel   string                 `yaml:"log_level"`
	Properties map[string]interface{} `yaml:"properties"`
}

// Finder is the interface that wraps the simple Find method that performs the
// finding of the plugins file in the user system.
type Finder interface {
	Find() (string, error)
}

type finder struct {
	osGetwd func() (string, error)
	osStat  func(string) (fs.FileInfo, error)
}

// NewFinder instantiates a default internal implementation of the Finder
// interface.
func NewFinder() Finder {
	return &finder{
		osGetwd: os.Getwd,
		osStat:  os.Stat,
	}
}

// Find finds the .aspectplugins file under a Bazel workspace. If the returned
// path is empty and no error was produced, the file doesn't exist.
func (f *finder) Find() (string, error) {
	cwd, err := f.osGetwd()
	if err != nil {
		return "", fmt.Errorf("failed to find .aspectplugins: %w", err)
	}
	for {
		workspacePath := path.Join(cwd, workspaceFilename)
		if _, err := f.osStat(workspacePath); err != nil {
			if !os.IsNotExist(err) {
				return "", fmt.Errorf("failed to find .aspectplugins: %w", err)
			}
			cwd = filepath.Dir(cwd)
			continue
		}
		aspectpluginsPath := path.Join(cwd, aspectpluginsFilename)
		if _, err := f.osStat(aspectpluginsPath); err != nil {
			if !os.IsNotExist(err) {
				return "", fmt.Errorf("failed to find .aspectplugins: %w", err)
			}
			break
		}
		return aspectpluginsPath, nil
	}
	return "", nil
}

// Parser is the interface that wraps the Parse method that performs the parsing
// of a plugins file.
type Parser interface {
	Parse(aspectpluginsPath string) ([]AspectPlugin, error)
}

type parser struct {
	ioutilReadFile      func(filename string) ([]byte, error)
	yamlUnmarshalStrict func(in []byte, out interface{}) (err error)
}

// NewParser instantiates a default internal implementation of the Parser
// interface.
func NewParser() Parser {
	return &parser{
		ioutilReadFile:      ioutil.ReadFile,
		yamlUnmarshalStrict: yaml.UnmarshalStrict,
	}
}

// Parse parses a plugins file.
func (p *parser) Parse(aspectpluginsPath string) ([]AspectPlugin, error) {
	if aspectpluginsPath == "" {
		return []AspectPlugin{}, nil
	}
	aspectpluginsData, err := p.ioutilReadFile(aspectpluginsPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse .aspectplugins: %w", err)
	}
	var aspectplugins []AspectPlugin
	if err := p.yamlUnmarshalStrict(aspectpluginsData, &aspectplugins); err != nil {
		return nil, fmt.Errorf("failed to parse .aspectplugins: %w", err)
	}
	return aspectplugins, nil
}
