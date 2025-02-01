package packet

import (
	"bytes"
	"crypto/ecdsa"
	"fmt"

	"github.com/Archisman-Mridha/ethereum-node-implementation/pkg/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rlp"
)

const PACKET_HEADER_SIZE = 32 + 65 + 1 // (in bytes).

type PacketHeader struct {
	// Exists to make the packet format recognizable when running multiple protocols on the same
	// UDP port. It serves no other purpose.
	// This is the Keccak256 hash of the packet content.
	Hash types.H256

	// Packet data of every packet is signed by the node's identity key.
	// This represents that ECDSA signature.
	Signature types.H520

	// Defines the type of the packet / message.
	Type PacketType
}

func newPacketHeader(
	packetData PacketData,
	nodePrivateKey *ecdsa.PrivateKey,
) (*PacketHeader, []byte, error) {
	encodedPacketData := new(bytes.Buffer)
	if err := rlp.Encode(encodedPacketData, packetData); err != nil {
		return nil, nil, fmt.Errorf("couldn't RLP encode packet data : %v", err)
	}

	signature, err := crypto.Sign(crypto.Keccak256(encodedPacketData.Bytes()), nodePrivateKey)
	if err != nil {
		return nil, nil, fmt.Errorf("couldn't generate packet data signature : %v", err)
	}

	encodedPacket := append(append(signature, packetData.GetType()), encodedPacketData.Bytes()...)
	hash := crypto.Keccak256(encodedPacket)

	encodedPacket = append(hash, encodedPacket...)

	packetHeader := &PacketHeader{
		Hash:      types.H256(hash),
		Signature: types.H520(signature),
		Type:      packetData.GetType(),
	}
	return packetHeader, encodedPacket, nil
}
