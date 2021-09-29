/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package hooks

import (
	"context"

	"aspect.build/cli/pkg/aspecterrors"
)

type Hooks struct {
	postBuild *hookList
}

func New() *Hooks {
	return &Hooks{
		postBuild: &hookList{},
	}
}

func (hooks *Hooks) RegisterPostBuild(fn PostBuildFn) {
	hooks.postBuild.insert(fn)
}

func (hooks *Hooks) ExecutePostBuild(ctx context.Context) *aspecterrors.ErrorList {
	errors := &aspecterrors.ErrorList{}
	node := hooks.postBuild.head
	for node != nil {
		if err := node.fn.(PostBuildFn)(ctx); err != nil {
			errors.Insert(err)
		}
		node = node.next
	}
	return errors
}

type PostBuildFn func(ctx context.Context) error

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
