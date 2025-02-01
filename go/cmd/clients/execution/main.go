package main

import (
	"context"
	"log/slog"
	"net/netip"
	"time"

	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/networking"
	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/networking/bootnode"
	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/networking/stacks/discovery/discv4/packet"
	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/utils/observability/logger"
	"golang.org/x/sync/errgroup"
)

func main() {
	ctx := context.Background()

	waitGroup, ctx := errgroup.WithContext(ctx)

	logger.SetupLogger(true, true)

	endpoint := packet.NewEndpointFromSocketAddress(netip.MustParseAddrPort("0.0.0.0:30303"))

	privateKey := getPrivateKey(ctx)

	_, err := networking.NewNetworkStack(ctx, waitGroup,
		&networking.NetworkStackArgs{
			Endpoint:       endpoint,
			BootNodeEnodes: bootnode.DEFAULT_BOOTNODE_ENODES,
			PrivateKey:     privateKey,
		},
	)
	if err != nil {
		slog.ErrorContext(ctx, "Failed starting the network stack", logger.Error(err))
	}

	time.Sleep(30 * time.Second)
}
