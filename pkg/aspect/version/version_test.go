/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package version_test

import (
	"strings"
	"testing"

	. "github.com/onsi/gomega"

	"aspect.build/cli/pkg/aspect/version"
	"aspect.build/cli/pkg/ioutils"
)

func TestVersion(t *testing.T) {
	t.Run("without release build info", func(t *testing.T) {
		g := NewGomegaWithT(t)
		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}
		v := version.New(streams)
		err := v.Run(nil, nil)
		g.Expect(err).To(BeNil())
		g.Expect(stdout.String()).To(Equal("Aspect version: unknown [not built with --stamp]\n"))
	})

	t.Run("with release build info", func(t *testing.T) {
		t.Run("git is clean", func(t *testing.T) {
			g := NewGomegaWithT(t)
			var stdout strings.Builder
			streams := ioutils.Streams{Stdout: &stdout}
			v := version.New(streams)
			v.BuildinfoRelease = "1.2.3"
			v.BuildinfoGitStatus = "clean"
			err := v.Run(nil, nil)
			g.Expect(err).To(BeNil())
			g.Expect(stdout.String()).To(Equal("Aspect version: 1.2.3\n"))
		})

		t.Run("git is dirty", func(t *testing.T) {
			g := NewGomegaWithT(t)
			var stdout strings.Builder
			streams := ioutils.Streams{Stdout: &stdout}
			v := version.New(streams)
			v.BuildinfoRelease = "1.2.3"
			v.BuildinfoGitStatus = ""
			err := v.Run(nil, nil)
			g.Expect(err).To(BeNil())
			g.Expect(stdout.String()).To(Equal("Aspect version: 1.2.3 (with local changes)\n"))
		})
	})

	t.Run("with --gnu_format", func(t *testing.T) {
		g := NewGomegaWithT(t)
		var stdout strings.Builder
		streams := ioutils.Streams{Stdout: &stdout}
		v := version.New(streams)
		v.GNUFormat = true
		v.BuildinfoRelease = "1.2.3"
		v.BuildinfoGitStatus = "clean"
		err := v.Run(nil, nil)
		g.Expect(err).To(BeNil())
		g.Expect(stdout.String()).To(Equal("Aspect 1.2.3\n"))
	})
}
