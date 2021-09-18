/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package clean_test

import (
	"testing"

	"github.com/golang/mock/gomock"
	. "github.com/onsi/gomega"

	"aspect.build/cli/pkg/aspect/clean"
	"aspect.build/cli/pkg/bazel/mock"
	"aspect.build/cli/pkg/ioutils"
)

func TestClean(t *testing.T) {

	t.Run("clean calls bazel clean", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		spawner := mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"clean"}).
			Return(0, nil)

		b := clean.New(ioutils.Streams{}, spawner)
		err := b.Run(nil, []string{})

		g.Expect(err).To(BeNil())
	})

	t.Run("clean expunge calls bazel clean expunge", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		spawner := mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"clean", "--expunge"}).
			Return(0, nil)

		b := clean.New(ioutils.Streams{}, spawner)
		b.Expunge = true
		err := b.Run(nil, []string{})

		g.Expect(err).To(BeNil())
	})

	t.Run("clean expunge_async calls bazel clean expunge_async", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		spawner := mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"clean", "--expunge_async"}).
			Return(0, nil)

		b := clean.New(ioutils.Streams{}, spawner)
		b.ExpungeAsync = true
		err := b.Run(nil, []string{})

		g.Expect(err).To(BeNil())
	})
}
