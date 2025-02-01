package packet

import "github.com/Archisman-Mridha/ethereum-node-implementation/pkg/types"

// Pong type packet is the reply to a Ping type packet.
// We will ignore unsolicited Pong type packets that do not contain the hash of the most recent
// corresponding Ping type packet (if it was sent).
type PongPacketData struct {
	To *Endpoint

	// Hash of the corresponding Ping type packet.
	PingHash types.H256

	// An absolute UNIX time stamp.
	// Expired packets will not be processed.
	Expiration uint64

	// ENR sequence number of the sender.
	ENRSequenceNumber *uint64 `rlp:"nil"`
}

func NewPongPacketData() *PongPacketData {
	return &PongPacketData{}
}

func (p *PongPacketData) GetType() PacketType {
	return PACKET_TYPE_PONG
}
