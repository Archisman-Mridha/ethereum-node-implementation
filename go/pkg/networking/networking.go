package networking

import (
	"context"
	"crypto/ecdsa"
	"fmt"

	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/networking/stacks/discovery"
	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/networking/stacks/discovery/discv4/packet"
	"golang.org/x/sync/errgroup"
)

type (
	/*
		Ethereum is a peer-to-peer network with thousands of nodes that must be able to communicate
		with one another using standardized protocols.

		There are two parts to the client software (execution clients and consensus clients), each with
		its own distinct networking stack.

		The execution layer's networking protocols is divided into two stacks : the Discovery stack
		and the DevP2P stack.
	*/
	NetworkStack struct {
		DiscoveryStack *discovery.DiscoveryStack
	}

	NetworkStackArgs struct {
		Endpoint       *packet.Endpoint
		PrivateKey     *ecdsa.PrivateKey
		BootNodeEnodes []string
	}
)

func NewNetworkStack(ctx context.Context,
	waitGroup *errgroup.Group,
	args *NetworkStackArgs,
) (*NetworkStack, error) {
	discoveryStack, err := discovery.NewDiscoveryStack(ctx, waitGroup, &discovery.DiscoveryStackArgs{
		Endpoint:       args.Endpoint,
		PrivateKey:     args.PrivateKey,
		BootNodeEnodes: args.BootNodeEnodes,
	})
	if err != nil {
		return nil, fmt.Errorf("couldn't start the discovery stack : %v", err)
	}

	networkStack := &NetworkStack{
		DiscoveryStack: discoveryStack,
	}
	return networkStack, nil
}
