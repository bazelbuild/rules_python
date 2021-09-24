/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package bazel

import (
	"encoding/base64"
	"fmt"
	"io"
	"io/ioutil"

	"google.golang.org/protobuf/proto"
)

func (b *Bazel) Flags() (map[string]*FlagInfo, error) {
	r, w := io.Pipe()
	decoder := base64.NewDecoder(base64.StdEncoding, r)
	bazelErrs := make(chan error, 1)
	defer close(bazelErrs)
	go func() {
		defer w.Close()
		_, err := b.RunCommand([]string{"help", "flags-as-proto"}, w)
		bazelErrs <- err
	}()

	helpProtoBytes, err := ioutil.ReadAll(decoder)
	if err != nil {
		return nil, fmt.Errorf("failed to get Bazel flags: %w", err)
	}

	if err := <-bazelErrs; err != nil {
		return nil, fmt.Errorf("failed to get Bazel flags: %w", err)
	}

	flagCollection := &FlagCollection{}
	if err := proto.Unmarshal(helpProtoBytes, flagCollection); err != nil {
		return nil, fmt.Errorf("failed to get Bazel flags: %w", err)
	}

	flags := make(map[string]*FlagInfo)
	for i := range flagCollection.FlagInfos {
		flags[*flagCollection.FlagInfos[i].Name] = flagCollection.FlagInfos[i]
	}

	return flags, nil
}
