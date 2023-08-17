// Copyright 2023 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

var (
	stdModulesStdin  io.WriteCloser
	stdModulesStdout io.Reader
	stdModulesMutex  sync.Mutex
	stdModulesSeen   map[string]struct{}
)

func startStdModuleProcess(ctx context.Context) {
	stdModulesSeen = make(map[string]struct{})

	stdModulesScriptRunfile, err := bazel.Runfile("python/std_modules")
	if err != nil {
		log.Printf("failed to initialize std_modules: %v\n", err)
		os.Exit(1)
	}

	cmd := exec.CommandContext(ctx, stdModulesScriptRunfile)

	cmd.Stderr = os.Stderr
	// All userland site-packages should be ignored.
	cmd.Env = []string{"PYTHONNOUSERSITE=1"}
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
		if err := cmd.Wait(); err != nil {
			log.Printf("failed to wait for std_modules: %v\n", err)
			os.Exit(1)
		}
	}()
}

func shutdownStdModuleProcess() {
	if err := stdModulesStdin.Close(); err != nil {
		fmt.Fprintf(os.Stderr, "error closing std module: %v", err)
	}
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
