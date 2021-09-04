package topics

import (
	"fmt"
	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"os"
)

func Read(topic string) string {
	rpath := "docs/help/topics/" + topic
	r, err := bazel.Runfile(rpath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to locate %s in runfiles: %v\n", rpath, err)
	}
	c, err := os.ReadFile(r)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read %s: %v\n", r, err)
	}
	return string(c)
}
