package bazel

import (
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
)

// LocateBazel determines which executable we call through to
func LocateBazel() string {
	// When installed in tools/bazel, bazelisk sets this variable
	bazelReal, ok := os.LookupEnv("BAZEL_REAL")
	if ok {
		return bazelReal
	}
	pathBazelisk, err := exec.LookPath("bazelisk")
	if err == nil {
		return pathBazelisk
	}
	pathBazel, err := exec.LookPath("bazel")
	if err == nil {
		return pathBazel
	}
	panic("Unable to locate bazel tool to wrap. Looked in $BAZEL_REAL, $PATH")
}

func Spawn(command string) {
	bazel := LocateBazel()
	cmd := exec.Command(bazel, command)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		log.Fatal(err)
	}

	slurpOut, _ := io.ReadAll(stdout)
	fmt.Printf("%s\n", slurpOut)

	slurpErr, _ := io.ReadAll(stderr)
	fmt.Fprintf(os.Stderr, "%s\n", slurpErr)

	if err := cmd.Wait(); err != nil {
		log.Fatal(err)
	}
}
