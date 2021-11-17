/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

// The fix-visibility is a plugin for the aspect CLI. When running in interactive
// mode, it offers to automatically fix visibility issues, otherwise, it prints to
// the terminal the buildozer commands necessary to perform the fix manually.
//
// This plugin is also a reference implementation of a plugin using the Go SDK.
// You will find the code below commented to your satisfaction.
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
	// config.NewConfigFor accepts a plugin implementation and returns the go-plugin
	// configuration required to serve the plugin to the CLI core.
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

// NewPlugin creates a new FixVisibilityPlugin, allowing dependencies to be
// injected.
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
	// First, verify if the received event is of the type Aborted. The visibility
	// issue events are emitted as ANALYSIS_FAILUE, so if there's an analysis
	// failure and the description of the event contains the known-issue string,
	// we perform a regex match to extract the targets. Note that strings.Contains
	// is much cheaper than relying on the regex matching, so we only call regex
	// when we are absolutely sure it will return a valid match.
	aborted := event.GetAborted()
	if aborted != nil &&
		aborted.Reason == buildeventstream.Aborted_ANALYSIS_FAILURE &&
		strings.Contains(aborted.Description, visibilityIssueSubstring) {
		matches := visibilityIssueRegex.FindStringSubmatch(aborted.Description)
		if len(matches) == 3 {
			// Here, we insert the matched targets in a linked list for processing
			// in the post-build hook.
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

	// For each collected visibility issue...
	for node := plugin.targetsToFix.head; node != nil; node = node.next {
		// ... we construct the label for the target we want to add to the target
		// being fixed.
		fromLabel, err := label.Parse(node.from)
		if err != nil {
			return fmt.Errorf("failed to fix visibility: %w", err)
		}
		fromLabel.Name = "__pkg__"

		// We need to verify if the target being fixed contains //visibility:private,
		// otherwise Bazel will yell at us since we will need to remove it to add
		// any package to the visibility attribute.
		hasPrivateVisibility, err := plugin.hasPrivateVisibility(node.toFix)
		if err != nil {
			return fmt.Errorf("failed to fix visibility: %w", err)
		}

		// We check whether it's running in interactive mode, if so, send a request
		// to prompt the user using the promptRunner injected by the CLI core in
		// this method.
		var applyFix bool
		if isInteractiveMode {
			applyFixPrompt := promptui.Prompt{
				Label:     "Would you like to apply the visibility fixes",
				IsConfirm: true,
			}
			_, err := promptRunner.Run(applyFixPrompt)
			// Since the prompt is a boolean, any non-nil error should represent a NO.
			applyFix = err == nil
		}

		// Here we either perform the fix automatically, or print the commands for
		// the user to perfom the fixes manually.
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
