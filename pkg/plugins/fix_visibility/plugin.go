/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package fix_visibility

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"

	"github.com/bazelbuild/bazel-gazelle/label"
	"github.com/bazelbuild/buildtools/edit"
	"github.com/manifoldco/promptui"
	isatty "github.com/mattn/go-isatty"
	buildv1 "google.golang.org/genproto/googleapis/devtools/build/v1"
)

type FixVisibilityPlugin struct {
	stdout            io.Writer
	buildozer         Runner
	isInteractiveMode bool
	applyFixPrompt    promptui.Prompt
	targetsToFix      *fixOrderedSet
}

func NewDefaultPlugin() *FixVisibilityPlugin {
	isInteractiveMode := isatty.IsTerminal(os.Stdout.Fd()) || isatty.IsCygwinTerminal(os.Stdout.Fd())
	applyFixPrompt := promptui.Prompt{
		Label:     "Would you like to apply the visibility fixes",
		IsConfirm: true,
	}
	return NewPlugin(os.Stdout, &buildozer{}, isInteractiveMode, applyFixPrompt)
}

func NewPlugin(
	stdout io.Writer,
	buildozer Runner,
	isInteractiveMode bool,
	applyFixPrompt promptui.Prompt,
) *FixVisibilityPlugin {
	return &FixVisibilityPlugin{
		stdout:            stdout,
		buildozer:         buildozer,
		isInteractiveMode: isInteractiveMode,
		targetsToFix:      &fixOrderedSet{nodes: make(map[fixNode]struct{})},
		applyFixPrompt:    applyFixPrompt,
	}
}

var visibilityIssueRegex = regexp.MustCompile(`.*target '(.*)' is not visible from target '(.*)'.*`)
var visibilityIssueSubstring = []byte("is not visible from target")

func (plugin *FixVisibilityPlugin) BEPEventCallback(event *buildv1.BuildEvent) error {
	bazelEvent := event.GetBazelEvent()
	if bazelEvent != nil {
		if !bytes.Contains(bazelEvent.Value, visibilityIssueSubstring) {
			return nil
		}
		matches := visibilityIssueRegex.FindSubmatch(bazelEvent.Value)
		if len(matches) != 3 {
			return nil
		}
		plugin.targetsToFix.insert(string(matches[1]), string(matches[2]))
	}
	return nil
}

const removePrivateVisibilityBuildozerCommand = "remove visibility //visibility:private"

func (plugin *FixVisibilityPlugin) PostBuildHook() error {
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
		if plugin.isInteractiveMode {
			_, err := plugin.applyFixPrompt.Run()
			applyFix = err == nil
		}

		addVisibilityBuildozerCommand := fmt.Sprintf("add visibility %s", fromLabel)
		if applyFix {
			if _, err := plugin.buildozer.Run(addVisibilityBuildozerCommand, node.toFix); err != nil {
				return fmt.Errorf("failed to fix visibility: %w", err)
			}
			if hasPrivateVisibility {
				if _, err := plugin.buildozer.Run(removePrivateVisibilityBuildozerCommand, node.toFix); err != nil {
					return fmt.Errorf("failed to fix visibility: %w", err)
				}
			}
		} else {
			fmt.Fprintf(plugin.stdout, "To fix the visibility errors, run:\n")
			fmt.Fprintf(plugin.stdout, "buildozer '%s' %s\n", addVisibilityBuildozerCommand, node.toFix)
			if hasPrivateVisibility {
				fmt.Fprintf(plugin.stdout, "buildozer '%s' %s\n", removePrivateVisibilityBuildozerCommand, node.toFix)
			}
		}
	}

	return nil
}

func (plugin *FixVisibilityPlugin) hasPrivateVisibility(toFix string) (bool, error) {
	visibility, err := plugin.buildozer.Run("print visibility", toFix)
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

type Runner interface {
	Run(args ...string) ([]byte, error)
}

type buildozer struct{}

func (b *buildozer) Run(args ...string) ([]byte, error) {
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
