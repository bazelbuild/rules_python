/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package ioutils

import "github.com/manifoldco/promptui"

// PromptRunner is the interface that wraps the promptui.Prompt and makes a call
// to it from the aspect CLI Core.
type PromptRunner interface {
	Run(prompt promptui.Prompt) (string, error)
}
