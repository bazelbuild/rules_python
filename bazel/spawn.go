package bazel

import (
	"github.com/bazelbuild/bazelisk/core"
	"github.com/bazelbuild/bazelisk/repositories"
)

// Spawn is similar to the main() function of bazelisk
// see https://github.com/bazelbuild/bazelisk/blob/7c3d9d5/bazelisk.go
func Spawn(command []string) (int, error) {
	gcs := &repositories.GCSRepo{}
	gitHub := repositories.CreateGitHubRepo(core.GetEnvOrConfig("BAZELISK_GITHUB_TOKEN"))
	// Fetch LTS releases, release candidates and Bazel-at-commits from GCS, forks and rolling releases from GitHub.
	// TODO(https://github.com/bazelbuild/bazelisk/issues/228): get rolling releases from GCS, too.
	repos := core.CreateRepositories(gcs, gcs, gitHub, gcs, gitHub, true)

	exitCode, err := core.RunBazelisk(command, repos)
	return exitCode, err
}
