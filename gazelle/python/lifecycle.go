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
	"context"
	_ "embed"
	"github.com/bazelbuild/bazel-gazelle/language"
	"log"
	"os"
)

var (
	//go:embed helper.zip
	helperZip  []byte
	helperPath string
)

type LifeCycleManager struct {
	language.BaseLifecycleManager
	pyzFilePath string
}

func (l *LifeCycleManager) Before(ctx context.Context) {
	helperPath = os.Getenv("GAZELLE_PYTHON_HELPER")
	if helperPath == "" {
		pyzFile, err := os.CreateTemp("", "python_zip_")
		if err != nil {
			log.Fatalf("failed to write parser zip: %v", err)
		}
		defer pyzFile.Close()
		helperPath = pyzFile.Name()
		l.pyzFilePath = helperPath
		if _, err := pyzFile.Write(helperZip); err != nil {
			log.Fatalf("cannot write %q: %v", helperPath, err)
		}
	}
	startParserProcess(ctx)
	startStdModuleProcess(ctx)
}

func (l *LifeCycleManager) DoneGeneratingRules() {
	shutdownParserProcess()
}

func (l *LifeCycleManager) AfterResolvingDeps(ctx context.Context) {
	shutdownStdModuleProcess()
	if l.pyzFilePath != "" {
		os.Remove(l.pyzFilePath)
	}
}
