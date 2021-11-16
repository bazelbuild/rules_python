/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package system

import (
	"fmt"
	"os/exec"

	hclog "github.com/hashicorp/go-hclog"
	goplugin "github.com/hashicorp/go-plugin"

	"aspect.build/cli/pkg/ioutils"
	"aspect.build/cli/pkg/plugin/sdk/v1alpha1/config"
	"aspect.build/cli/pkg/plugin/sdk/v1alpha1/plugin"
)

// PluginSystem is the interface that defines all the methods for the aspect CLI
// plugin system intended to be used by the Core.
type PluginSystem interface {
	Configure(streams ioutils.Streams) error
	PluginList() *PluginList
	TearDown()
}

type pluginSystem struct {
	finder        Finder
	parser        Parser
	clientFactory ClientFactory
	clients       []ClientProvider
	plugins       *PluginList
}

// NewPluginSystem instantiates a default internal implementation of the
// PluginSystem interface.
func NewPluginSystem() PluginSystem {
	return &pluginSystem{
		finder:        NewFinder(),
		parser:        NewParser(),
		clientFactory: &clientFactory{},
		plugins:       &PluginList{},
	}
}

// Configure configures the plugin system.
func (ps *pluginSystem) Configure(streams ioutils.Streams) error {
	aspectpluginsPath, err := ps.finder.Find()
	if err != nil {
		return fmt.Errorf("failed to configure plugin system: %w", err)
	}
	aspectplugins, err := ps.parser.Parse(aspectpluginsPath)
	if err != nil {
		return fmt.Errorf("failed to configure plugin system: %w", err)
	}

	ps.clients = make([]ClientProvider, 0, len(aspectplugins))
	for _, aspectplugin := range aspectplugins {
		logLevel := hclog.LevelFromString(aspectplugin.LogLevel)
		if logLevel == hclog.NoLevel {
			logLevel = hclog.Error
		}
		pluginLogger := hclog.New(&hclog.LoggerOptions{
			Name:  aspectplugin.Name,
			Level: logLevel,
		})
		// TODO(f0rmiga): make this loop concurrent so that all plugins are
		// configured faster.
		clientConfig := &goplugin.ClientConfig{
			HandshakeConfig:  config.Handshake,
			Plugins:          config.PluginMap,
			Cmd:              exec.Command(aspectplugin.From),
			AllowedProtocols: []goplugin.Protocol{goplugin.ProtocolGRPC},
			SyncStdout:       streams.Stdout,
			SyncStderr:       streams.Stderr,
			Logger:           pluginLogger,
		}
		client := ps.clientFactory.New(clientConfig)
		ps.clients = append(ps.clients, client)

		rpcClient, err := client.Client()
		if err != nil {
			return fmt.Errorf("failed to configure plugin system: %w", err)
		}

		rawplugin, err := rpcClient.Dispense(config.DefaultPluginName)
		if err != nil {
			return fmt.Errorf("failed to configure plugin system: %w", err)
		}

		aspectplugin := rawplugin.(plugin.Plugin)
		ps.plugins.insert(aspectplugin)
	}

	return nil
}

// TearDown tears down the plugin system, making all the necessary actions to
// clean up the system.
func (ps *pluginSystem) TearDown() {
	for _, client := range ps.clients {
		client.Kill()
	}
}

// PluginList returns the list of configures plugins.
func (ps *pluginSystem) PluginList() *PluginList {
	return ps.plugins
}

// ClientFactory hides the call to goplugin.NewClient.
type ClientFactory interface {
	New(*goplugin.ClientConfig) ClientProvider
}

type clientFactory struct{}

// New calls the goplugin.NewClient with the given config.
func (*clientFactory) New(config *goplugin.ClientConfig) ClientProvider {
	return goplugin.NewClient(config)
}

// ClientProvider is an interface for goplugin.Client returned by
// goplugin.NewClient.
type ClientProvider interface {
	Client() (goplugin.ClientProtocol, error)
	Kill()
}

// PluginList implements a simple linked list for the parsed plugins from the
// plugins file.
type PluginList struct {
	Head *PluginNode
	tail *PluginNode
}

func (l *PluginList) insert(p plugin.Plugin) {
	node := &PluginNode{Plugin: p}
	if l.Head == nil {
		l.Head = node
	} else {
		l.tail.Next = node
	}
	l.tail = node
}

// PluginNode is a node in the PluginList linked list.
type PluginNode struct {
	Next   *PluginNode
	Plugin plugin.Plugin
}
