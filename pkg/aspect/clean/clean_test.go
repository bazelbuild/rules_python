/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package clean_test

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"

	"github.com/golang/mock/gomock"
	. "github.com/onsi/gomega"
	"github.com/spf13/viper"

	"aspect.build/cli/pkg/aspect/clean"
	"aspect.build/cli/pkg/bazel/mock"
	"aspect.build/cli/pkg/ioutils"
)

type confirm struct{}

func (p confirm) Run() (string, error) {
	return "", nil
}

type deny struct{}

func (p deny) Run() (string, error) {
	return "", fmt.Errorf("said no")
}

type chooseReclaim struct{}

func (p chooseReclaim) Run() (int, string, error) {
	return 0, clean.ReclaimOption, nil
}

type chooseNonIncremental struct{}

func (p chooseNonIncremental) Run() (int, string, error) {
	return 2, clean.NonIncrementalOption, nil
}

type chooseInvalidateRepos struct{}

func (p chooseInvalidateRepos) Run() (int, string, error) {
	return 3, clean.InvalidateReposOption, nil
}

type chooseWorkaround struct{}

func (p chooseWorkaround) Run() (int, string, error) {
	return 4, clean.WorkaroundOption, nil
}

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

		b := clean.New(ioutils.Streams{}, spawner, false)
		g.Expect(b.Run(nil, []string{})).Should(Succeed())
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

		b := clean.New(ioutils.Streams{}, spawner, false)
		b.Expunge = true
		g.Expect(b.Run(nil, []string{})).Should(Succeed())
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

		b := clean.New(ioutils.Streams{}, spawner, false)
		b.ExpungeAsync = true
		g.Expect(b.Run(nil, []string{})).Should(Succeed())
	})

	t.Run("interactive clean prompts for usage, option 1", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		spawner := mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"clean"}).
			Return(0, nil)

		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}
		b := clean.New(streams, spawner, true)

		b.Behavior = chooseReclaim{}
		b.Remember = deny{}

		g.Expect(b.Run(nil, []string{})).Should(Succeed())
		g.Expect(stdout.String()).To(ContainSubstring("skip this prompt"))
	})

	t.Run("interactive clean prompts for usage, option 1 and save", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		spawner := mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"clean"}).
			Return(0, nil).AnyTimes()

		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}
		b := clean.New(streams, spawner, true)

		viper := *viper.New()
		cfg, err := os.CreateTemp(os.Getenv("TEST_TMPDIR"), "cfg***.ini")
		g.Expect(err).To(BeNil())

		viper.SetConfigFile(cfg.Name())
		b.Behavior = chooseReclaim{}
		b.Remember = confirm{}
		b.Prefs = viper
		g.Expect(b.Run(nil, []string{})).Should(Succeed())
		g.Expect(stdout.String()).To(ContainSubstring("skip this prompt"))

		// Recorded your preference for next time
		content, err := ioutil.ReadFile(cfg.Name())
		g.Expect(err).To(BeNil())
		g.Expect(string(content)).To(Equal("[clean]\nskip_prompt=true\n\n"))

		// If we run it again, there should be no prompt
		c := clean.New(streams, spawner, true)
		c.Prefs = viper
		g.Expect(c.Run(nil, []string{})).Should(Succeed())
	})

	t.Run("interactive clean prompts for usage, option 2", func(t *testing.T) {
		g := NewGomegaWithT(t)
		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}

		c := clean.New(streams, nil, true)
		c.Behavior = chooseNonIncremental{}
		g.Expect(c.Run(nil, []string{})).Should(Succeed())
		g.Expect(stdout.String()).To(ContainSubstring("use the --output_base flag"))
	})

	t.Run("interactive clean prompts for usage, option 3", func(t *testing.T) {
		g := NewGomegaWithT(t)
		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}

		c := clean.New(streams, nil, true)
		c.Behavior = chooseInvalidateRepos{}
		g.Expect(c.Run(nil, []string{})).Should(Succeed())
		g.Expect(stdout.String()).To(ContainSubstring("aspect sync --configure"))
	})

	t.Run("interactive clean prompts for usage, option 5", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		spawner := mock.NewMockSpawner(ctrl)
		spawner.
			EXPECT().
			Spawn([]string{"clean"}).
			Return(0, nil)

		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}

		c := clean.New(streams, spawner, true)
		c.Behavior = chooseWorkaround{}
		c.Workaround = confirm{}
		g.Expect(c.Run(nil, []string{})).Should(Succeed())
		g.Expect(stdout.String()).To(ContainSubstring("recommend you file a bug"))
	})
}
