/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package bazel_test

import (
	"testing"

	. "github.com/onsi/gomega"

	"aspect.build/cli/pkg/bazel"
)

func TestBazel(t *testing.T) {
	t.Run("satisfies the Spawner interface", func(t *testing.T) {
		g := NewGomegaWithT(t)
		var bzl bazel.Spawner = bazel.New()
		g.Expect(bzl).To(Not(BeNil()))
	})
}
