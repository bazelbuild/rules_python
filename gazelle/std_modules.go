package python

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

var (
	stdModulesStdin  io.Writer
	stdModulesStdout io.Reader
	stdModulesMutex  sync.Mutex
	stdModulesSeen   map[string]struct{}
)

func init() {
	stdModulesSeen = make(map[string]struct{})

	stdModulesScriptRunfile, err := bazel.Runfile("gazelle/std_modules")
	if err != nil {
		log.Printf("failed to initialize std_modules: %v\n", err)
		os.Exit(1)
	}

	ctx := context.Background()
	ctx, stdModulesCancel := context.WithTimeout(ctx, time.Minute*5)
	cmd := exec.CommandContext(ctx, stdModulesScriptRunfile)

	cmd.Stderr = os.Stderr
	cmd.Env = []string{}

	stdin, err := cmd.StdinPipe()
	if err != nil {
		log.Printf("failed to initialize std_modules: %v\n", err)
		os.Exit(1)
	}
	stdModulesStdin = stdin

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Printf("failed to initialize std_modules: %v\n", err)
		os.Exit(1)
	}
	stdModulesStdout = stdout

	if err := cmd.Start(); err != nil {
		log.Printf("failed to initialize std_modules: %v\n", err)
		os.Exit(1)
	}

	go func() {
		defer stdModulesCancel()
		if err := cmd.Wait(); err != nil {
			log.Printf("failed to wait for std_modules: %v\n", err)
			os.Exit(1)
		}
	}()
}

func isStdModule(m module) (bool, error) {
	if _, seen := stdModulesSeen[m.Name]; seen {
		return true, nil
	}
	stdModulesMutex.Lock()
	defer stdModulesMutex.Unlock()

	fmt.Fprintf(stdModulesStdin, "%s\n", m.Name)

	stdoutReader := bufio.NewReader(stdModulesStdout)
	line, err := stdoutReader.ReadString('\n')
	if err != nil {
		return false, err
	}
	if len(line) == 0 {
		return false, fmt.Errorf("unexpected empty output from std_modules")
	}

	isStd, err := strconv.ParseBool(strings.TrimSpace(line))
	if err != nil {
		return false, err
	}

	if isStd {
		stdModulesSeen[m.Name] = struct{}{}
		return true, nil
	}
	return false, nil
}
