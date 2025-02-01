package bootnode

import (
	"encoding/hex"
	"errors"
	"fmt"
	"net/netip"
	"strings"

	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/types"
)

/*
When a new node joins the Ethereum network it needs to connect to nodes that are already on the
network in order to then discover new peers. These entry points into the Ethereum network are
called bootnodes.

	Bootnodes are full nodes that are not behind a NAT (Network Address Translation).

	Clients usually have a list of bootnodes hardcoded into them. These bootnodes are typically run
	by the Ethereum Foundation's devops team or client teams themselves.

	NOTE : Bootnodes are not the same as static nodes. Static nodes are called over and over again,
	      whereas bootnodes are only called upon if there are not enough peers to connect to and a
	      node needs to bootstrap some new connections.
*/
type BootNode struct {
	NodeID       types.H512
	SocketAddres netip.AddrPort
}

// Creates a BootNode instance out of the given enode.
// The instance is then returned.
func NewBootNode(enode string) (*BootNode, error) {
	if !strings.HasPrefix(enode, "enode://") {
		return nil, errors.New("invalid enode : doesn't start with enode://")
	}

	hexEncodedNodeID := enode[8:136]
	nodeID, err := hex.DecodeString(hexEncodedNodeID)
	if err != nil {
		return nil, fmt.Errorf("couldn't decode the node-id : %v", err)
	}

	encodedSocketAddress := enode[137:]
	socketAddress, err := netip.ParseAddrPort(encodedSocketAddress)
	if err != nil {
		return nil, fmt.Errorf("couldn't parse the socket address : %v", err)
	}

	bootNode := &BootNode{
		NodeID:       types.H512(nodeID),
		SocketAddres: socketAddress,
	}
	return bootNode, nil
}
