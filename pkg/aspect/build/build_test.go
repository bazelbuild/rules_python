/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package build_test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/golang/mock/gomock"
	. "github.com/onsi/gomega"

	"aspect.build/cli/pkg/aspect/build"
	"aspect.build/cli/pkg/aspecterrors"
	"aspect.build/cli/pkg/bazel/mock"
	"aspect.build/cli/pkg/ioutils"
)

func TestBuild(t *testing.T) {
	t.Run("when the bazel runner fails, the aspect build fails", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}
		spawner := mock.NewMockSpawner(ctrl)
		expectErr := &aspecterrors.ExitError{
			Err:      fmt.Errorf("failed to run bazel build"),
			ExitCode: 5,
		}
		spawner.
			EXPECT().
			Spawn([]string{"build", "//..."}).
			Return(expectErr.ExitCode, expectErr.Err)

		b := build.New(streams, spawner)
		err := b.Run(nil, []string{"//..."})

		g.Expect(err).To(Equal(expectErr))
	})

	t.Run("when the bazel runner succeeds, the aspect build succeeds", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}
		spawner := mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"build", "//..."}).
			Return(0, nil)

		b := build.New(streams, spawner)
		err := b.Run(nil, []string{"//..."})

		g.Expect(err).To(BeNil())
	})
}
