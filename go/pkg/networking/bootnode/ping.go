package bootnode

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"log/slog"
	"net"

	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/networking/stacks/discovery/discv4/packet"
)

type PingBootNodeArgs struct {
	Connection     *net.UDPConn
	SelfEndpoint   *packet.Endpoint
	SelfPrivateKey *ecdsa.PrivateKey
	Enodes         []string
}

func PingBootNodes(ctx context.Context, args *PingBootNodeArgs) error {
	for _, enode := range args.Enodes {
		bootNode, err := NewBootNode(enode)
		if err != nil {
			return fmt.Errorf("couldn't parse boot-node enode : %v", err)
		}

		bootNodeEndpoint := packet.NewEndpointFromSocketAddress(bootNode.SocketAddres)

		pingPacketData := packet.NewPingPacketData(bootNodeEndpoint, args.SelfEndpoint)
		_, encodedPingPacket, err := packet.NewPacket(pingPacketData, args.SelfPrivateKey)
		if err != nil {
			return fmt.Errorf("couldn't construct ping packet : %v", err)
		}

		_, err = args.Connection.Write(encodedPingPacket)
		slog.InfoContext(ctx, "Sent ping packet to boot-node", slog.String("enode", enode))
	}
	return nil
}
