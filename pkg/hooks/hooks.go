/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package hooks

import (
	"aspect.build/cli/pkg/aspecterrors"
	"aspect.build/cli/pkg/ioutils"
)

// Hooks represent the possible hook points from the plugin system. It accepts
// registrations and can execute them as requested at the appropriate times.
type Hooks struct {
	postBuild *hookList
}

// New instantiates a new Hooks.
func New() *Hooks {
	return &Hooks{
		postBuild: &hookList{},
	}
}

// RegisterPostBuild registers a post-build hook function.
func (hooks *Hooks) RegisterPostBuild(fn PostBuildFn) {
	hooks.postBuild.insert(fn)
}

// ExecutePostBuild executes the post-build hook functions in sequence they were
// registered.
func (hooks *Hooks) ExecutePostBuild(isInteractiveMode bool) *aspecterrors.ErrorList {
	errors := &aspecterrors.ErrorList{}
	node := hooks.postBuild.head
	for node != nil {
		// promptRunner is nil here because it has to satisfy the PostBuild
		// signature to comply with the go-plugin library. The real promptRunner is
		// instantiated when the gRPC call is made.
		if err := node.fn.(PostBuildFn)(isInteractiveMode, nil); err != nil {
			errors.Insert(err)
		}
		node = node.next
	}
	return errors
}

// PostBuildFn matches the plugin PostBuildHook method signature.
type PostBuildFn func(isInteractiveMode bool, promptRunner ioutils.PromptRunner) error

type hookList struct {
	head *hookNode
	tail *hookNode
}

func (l *hookList) insert(fn interface{}) {
	node := &hookNode{fn: fn}
	if l.head == nil {
		l.head = node
	} else {
		l.tail.next = node
	}
	l.tail = node
}

type hookNode struct {
	next *hookNode
	fn   interface{}
}
