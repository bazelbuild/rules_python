/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package main

import (
	"bytes"
	"fmt"
	"os"
	"regexp"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/buildtools/edit"
	goplugin "github.com/hashicorp/go-plugin"
	"github.com/manifoldco/promptui"

	buildeventstream "aspect.build/cli/bazel/buildeventstream/proto"
	"aspect.build/cli/pkg/ioutils"
	"aspect.build/cli/pkg/plugin/sdk/v1alpha1/config"
)

func main() {
	goplugin.Serve(config.NewConfigFor(NewDefaultPlugin()))
}

// FixVisibilityPlugin implements an aspect CLI plugin.
type FixVisibilityPlugin struct {
	buildozer    runner
	targetsToFix *fixOrderedSet
}

// NewDefaultPlugin creates a new FixVisibilityPlugin with the default
// dependencies.
func NewDefaultPlugin() *FixVisibilityPlugin {
	return NewPlugin(&buildozer{})
}

// NewPlugin creates a new FixVisibilityPlugin.
func NewPlugin(buildozer runner) *FixVisibilityPlugin {
	return &FixVisibilityPlugin{
		buildozer:    buildozer,
		targetsToFix: &fixOrderedSet{nodes: make(map[fixNode]struct{})},
	}
}

const visibilityIssueSubstring = "is not visible from target"

var visibilityIssueRegex = regexp.MustCompile(fmt.Sprintf(`.*target '(.*)' %s '(.*)'.*`, visibilityIssueSubstring))

// BEPEventCallback satisfies the Plugin interface. It process all the analysis
// failures that represent a visibility issue, collecting them for later
// processing in the post-build hook execution.
func (plugin *FixVisibilityPlugin) BEPEventCallback(event *buildeventstream.BuildEvent) error {
	aborted := event.GetAborted()
	if aborted != nil &&
		aborted.Reason == buildeventstream.Aborted_ANALYSIS_FAILURE &&
		strings.Contains(aborted.Description, visibilityIssueSubstring) {
		matches := visibilityIssueRegex.FindStringSubmatch(aborted.Description)
		if len(matches) == 3 {
			plugin.targetsToFix.insert(matches[1], matches[2])
		}
	}
	return nil
}

const removePrivateVisibilityBuildozerCommand = "remove visibility //visibility:private"

// PostBuildHook satisfies the Plugin interface. It prompts the user for
// automatic fixes when in interactive mode. If the user rejects the automatic
// fixes, or if running in non-interactive mode, the commands to perform the fixes
// are printed to the terminal.
func (plugin *FixVisibilityPlugin) PostBuildHook(
	isInteractiveMode bool,
	promptRunner ioutils.PromptRunner,
) error {
	if plugin.targetsToFix.size == 0 {
		return nil
	}

	for node := plugin.targetsToFix.head; node != nil; node = node.next {
		fromLabel, err := label.Parse(node.from)
		if err != nil {
			return fmt.Errorf("failed to fix visibility: %w", err)
		}
		fromLabel.Name = "__pkg__"

		hasPrivateVisibility, err := plugin.hasPrivateVisibility(node.toFix)
		if err != nil {
			return fmt.Errorf("failed to fix visibility: %w", err)
		}

		var applyFix bool
		if isInteractiveMode {
			applyFixPrompt := promptui.Prompt{
				Label:     "Would you like to apply the visibility fixes",
				IsConfirm: true,
			}
			_, err := promptRunner.Run(applyFixPrompt)
			applyFix = err == nil
		}

		addVisibilityBuildozerCommand := fmt.Sprintf("add visibility %s", fromLabel)
		if applyFix {
			if _, err := plugin.buildozer.run(addVisibilityBuildozerCommand, node.toFix); err != nil {
				return fmt.Errorf("failed to fix visibility: %w", err)
			}
			if hasPrivateVisibility {
				if _, err := plugin.buildozer.run(removePrivateVisibilityBuildozerCommand, node.toFix); err != nil {
					return fmt.Errorf("failed to fix visibility: %w", err)
				}
			}
		} else {
			fmt.Fprintf(os.Stdout, "To fix the visibility errors, run:\n")
			fmt.Fprintf(os.Stdout, "buildozer '%s' %s\n", addVisibilityBuildozerCommand, node.toFix)
			if hasPrivateVisibility {
				fmt.Fprintf(os.Stdout, "buildozer '%s' %s\n", removePrivateVisibilityBuildozerCommand, node.toFix)
			}
		}
	}

	return nil
}

func (plugin *FixVisibilityPlugin) hasPrivateVisibility(toFix string) (bool, error) {
	visibility, err := plugin.buildozer.run("print visibility", toFix)
	if err != nil {
		return false, fmt.Errorf("failed to check if target has private visibility: %w", err)
	}
	return bytes.Contains(visibility, []byte("//visibility:private")), nil
}

type fixOrderedSet struct {
	head  *fixNode
	tail  *fixNode
	nodes map[fixNode]struct{}
	size  int
}

func (s *fixOrderedSet) insert(toFix, from string) {
	node := fixNode{
		toFix: toFix,
		from:  from,
	}
	if _, exists := s.nodes[node]; !exists {
		s.nodes[node] = struct{}{}
		if s.head == nil {
			s.head = &node
		} else {
			s.tail.next = &node
		}
		s.tail = &node
		s.size++
	}
}

type fixNode struct {
	next  *fixNode
	toFix string
	from  string
}

type runner interface {
	run(args ...string) ([]byte, error)
}

type buildozer struct{}

func (b *buildozer) run(args ...string) ([]byte, error) {
	var stdout bytes.Buffer
	var stderr strings.Builder
	edit.ShortenLabelsFlag = true
	edit.DeleteWithComments = true
	opts := &edit.Options{
		OutWriter: &stdout,
		ErrWriter: &stderr,
		NumIO:     200,
	}
	if ret := edit.Buildozer(opts, args); ret != 0 {
		return stdout.Bytes(), fmt.Errorf("failed to run buildozer: exit code %d: %s", ret, stderr.String())
	}
	return stdout.Bytes(), nil
}
