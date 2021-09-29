/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package build_test

import (
	"context"
	"fmt"
	"strings"
	"testing"

	"github.com/golang/mock/gomock"
	. "github.com/onsi/gomega"

	"aspect.build/cli/pkg/aspect/build"
	bep_mock "aspect.build/cli/pkg/aspect/build/bep/mock"
	"aspect.build/cli/pkg/aspecterrors"
	bazel_mock "aspect.build/cli/pkg/bazel/mock"
	"aspect.build/cli/pkg/hooks"
	"aspect.build/cli/pkg/ioutils"
)

func TestBuild(t *testing.T) {
	t.Run("when the BES backend setup fails, the aspect build fails", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		streams := ioutils.Streams{}
		spawner := bazel_mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn(gomock.Any()).
			Times(0)
		besBackend := bep_mock.NewMockBESBackend(ctrl)
		setupErr := fmt.Errorf("failed setup")
		besBackend.
			EXPECT().
			Setup().
			Return(setupErr).
			Times(1)
		besBackend.
			EXPECT().
			ServeWait(gomock.Any()).
			Times(0)
		besBackend.
			EXPECT().
			Addr().
			Times(0)
		besBackend.
			EXPECT().
			GracefulStop().
			Times(0)
		besBackend.
			EXPECT().
			Errors().
			Times(0)

		hooks := hooks.New()
		b := build.New(streams, spawner, besBackend, hooks)
		ctx := context.Background()
		err := b.Run(ctx, nil, []string{"//..."})

		g.Expect(err).To(MatchError(fmt.Errorf("failed to run build command: %w", setupErr)))
	})

	t.Run("when the BES backend serve and wait fails, the aspect build fails", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		streams := ioutils.Streams{}
		spawner := bazel_mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn(gomock.Any()).
			Times(0)
		besBackend := bep_mock.NewMockBESBackend(ctrl)
		serveWaitErr := fmt.Errorf("failed serve and wait")
		besBackend.
			EXPECT().
			Setup().
			Return(nil).
			Times(1)
		besBackend.
			EXPECT().
			ServeWait(gomock.Any()).
			Return(serveWaitErr).
			Times(1)
		besBackend.
			EXPECT().
			Addr().
			Times(0)
		besBackend.
			EXPECT().
			GracefulStop().
			Times(0)
		besBackend.
			EXPECT().
			Errors().
			Times(0)

		hooks := hooks.New()
		b := build.New(streams, spawner, besBackend, hooks)
		ctx := context.Background()
		err := b.Run(ctx, nil, []string{"//..."})

		g.Expect(err).To(MatchError(fmt.Errorf("failed to run build command: %w", serveWaitErr)))
	})

	t.Run("when the bazel runner fails, the aspect build fails", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		streams := ioutils.Streams{}
		spawner := bazel_mock.NewMockSpawner(ctrl)
		expectErr := &aspecterrors.ExitError{
			Err:      fmt.Errorf("failed to run bazel build"),
			ExitCode: 5,
		}
		spawner.
			EXPECT().
			Spawn([]string{"build", "--bes_backend=grpc://127.0.0.1:12345", "//..."}).
			Return(expectErr.ExitCode, expectErr.Err)
		besBackend := bep_mock.NewMockBESBackend(ctrl)
		besBackend.
			EXPECT().
			Setup().
			Return(nil).
			Times(1)
		besBackend.
			EXPECT().
			ServeWait(gomock.Any()).
			Return(nil).
			Times(1)
		besBackend.
			EXPECT().
			Addr().
			Return("127.0.0.1:12345").
			Times(1)
		besBackend.
			EXPECT().
			GracefulStop().
			Times(1)
		besBackend.
			EXPECT().
			Errors().
			Times(1)

		hooks := hooks.New()
		b := build.New(streams, spawner, besBackend, hooks)
		ctx := context.Background()
		err := b.Run(ctx, nil, []string{"//..."})

		g.Expect(err).To(MatchError(expectErr))
	})

	t.Run("when a plugin fails, the aspect build fails", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		var stderr strings.Builder
		streams := ioutils.Streams{Stderr: &stderr}
		spawner := bazel_mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"build", "--bes_backend=grpc://127.0.0.1:12345", "//..."}).
			Return(0, nil)
		besBackend := bep_mock.NewMockBESBackend(ctrl)
		besBackend.
			EXPECT().
			Setup().
			Return(nil).
			Times(1)
		besBackend.
			EXPECT().
			ServeWait(gomock.Any()).
			Return(nil).
			Times(1)
		besBackend.
			EXPECT().
			Addr().
			Return("127.0.0.1:12345").
			Times(1)
		besBackend.
			EXPECT().
			GracefulStop().
			Times(1)
		besBackend.
			EXPECT().
			Errors().
			Return([]error{
				fmt.Errorf("error 1"),
				fmt.Errorf("error 2"),
			}).
			Times(1)

		hooks := hooks.New()
		b := build.New(streams, spawner, besBackend, hooks)
		ctx := context.Background()
		err := b.Run(ctx, nil, []string{"//..."})

		g.Expect(err).To(MatchError(&aspecterrors.ExitError{ExitCode: 1}))
		g.Expect(stderr.String()).To(Equal("Error: failed to run build command: error 1\nError: failed to run build command: error 2\n"))
	})

	t.Run("when the bazel runner succeeds, the aspect build succeeds", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		streams := ioutils.Streams{}
		spawner := bazel_mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"build", "--bes_backend=grpc://127.0.0.1:12345", "//..."}).
			Return(0, nil)
		besBackend := bep_mock.NewMockBESBackend(ctrl)
		besBackend.
			EXPECT().
			Setup().
			Return(nil).
			Times(1)
		besBackend.
			EXPECT().
			ServeWait(gomock.Any()).
			Return(nil).
			Times(1)
		besBackend.
			EXPECT().
			Addr().
			Return("127.0.0.1:12345").
			Times(1)
		besBackend.
			EXPECT().
			GracefulStop().
			Times(1)
		besBackend.
			EXPECT().
			Errors().
			Return([]error{}).
			Times(1)

		hooks := hooks.New()
		b := build.New(streams, spawner, besBackend, hooks)
		ctx := context.Background()
		err := b.Run(ctx, nil, []string{"//..."})

		g.Expect(err).To(BeNil())
	})
}
