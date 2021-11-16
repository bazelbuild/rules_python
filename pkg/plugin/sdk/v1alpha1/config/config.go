/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package config

import (
	goplugin "github.com/hashicorp/go-plugin"

	"aspect.build/cli/pkg/plugin/sdk/v1alpha1/plugin"
)

// DefaultPluginName is the name each aspect plugin must provide.
const DefaultPluginName = "aspectplugin"

// Handshake is the shared handshake config for the v1alpha1 protocol.
var Handshake = goplugin.HandshakeConfig{
	ProtocolVersion:  1,
	MagicCookieKey:   "PLUGIN",
	MagicCookieValue: "ASPECT",
}

// PluginMap represents the plugin interfaces allowed to be implemented by a
// plugin executable.
var PluginMap = map[string]goplugin.Plugin{
	DefaultPluginName: &plugin.GRPCPlugin{},
}

// NewConfigFor returns the default configuration for the passed Plugin
// implementation.
func NewConfigFor(p plugin.Plugin) *goplugin.ServeConfig {
	return &goplugin.ServeConfig{
		HandshakeConfig: Handshake,
		Plugins: map[string]goplugin.Plugin{
			DefaultPluginName: &plugin.GRPCPlugin{Impl: p},
		},
		GRPCServer: goplugin.DefaultGRPCServer,
	}
}
