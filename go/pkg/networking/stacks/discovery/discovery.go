package discovery

import (
	"context"
	"crypto/ecdsa"
	"log/slog"
	"net"
	"net/netip"

	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/networking/bootnode"
	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/networking/stacks/discovery/discv4/packet"
	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/utils/assert"
	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/utils/observability/logger"
	"golang.org/x/sync/errgroup"
)

const MAX_PACKET_SIZE = 1280 // (in bytes)

type (
	DiscoveryStack struct {
		endpoint   *packet.Endpoint
		connection *net.UDPConn
	}

	DiscoveryStackArgs struct {
		Endpoint       *packet.Endpoint
		PrivateKey     *ecdsa.PrivateKey
		BootNodeEnodes []string
	}
)

func NewDiscoveryStack(ctx context.Context,
	waitGroup *errgroup.Group,
	args *DiscoveryStackArgs,
) (*DiscoveryStack, error) {
	ctx = logger.AppendSlogAttributesToCtx(ctx, []slog.Attr{
		slog.String("component", "networking/discovery-stack"),
	})

	socketAddress := netip.AddrPortFrom(args.Endpoint.IPAddress, args.Endpoint.UDPPort)

	connection, err := net.ListenUDP("udp", net.UDPAddrFromAddrPort(socketAddress))
	assert.AssertErrNil(ctx, err, "Failed starting UDP server")

	bootnode.PingBootNodes(ctx, &bootnode.PingBootNodeArgs{
		Connection:     connection,
		SelfEndpoint:   args.Endpoint,
		SelfPrivateKey: args.PrivateKey,
		Enodes:         args.BootNodeEnodes,
	})

	discoveryStack := &DiscoveryStack{
		endpoint:   args.Endpoint,
		connection: connection,
	}
	return discoveryStack, nil
}

func (d *DiscoveryStack) readAndProcessPackets(ctx context.Context) {
	for {
		encodedPacket := make([]byte, MAX_PACKET_SIZE)
		if _, err := d.connection.Read(encodedPacket); err != nil {
			slog.ErrorContext(ctx, "Failed reading packet from connection", logger.Error(err))
			continue
		}

		packet, err := packet.DecodeRLP(encodedPacket)
		if err != nil {
			slog.ErrorContext(ctx, "Failed RLP decoding received packet", logger.Error(err))
			continue
		}

		slog.InfoContext(ctx, "Received packet", slog.Any("packet", packet))
	}
}
