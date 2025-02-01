package packet

import "time"

/*
When a Ping type packet is received, the recipient should reply with a Pong type packet. It may
also consider the sender for addition into the local table.

	If no communication with the sender has occurred within the last 12h, a ping should be sent in
	addition to pong in order to receive an endpoint proof.

	Packets that mismatch the discovery protocol version we're using, will be ignored.
*/
type PingPacketData struct {
	// The Discovery protocol version the message sender is using.
	// Must be set to 4.
	Version byte

	From *Endpoint
	To   *Endpoint

	// An absolute UNIX time stamp.
	// Expired packets will not be processed.
	Expiration uint64

	// ENR sequence number of the sender.
	ENRSequenceNumber *uint64 `rlp:"nil"`
}

// Constructs and returns an instance of the PingPacketData.
// The expiration time set to 20 seconds from the current time.
func NewPingPacketData(from, to *Endpoint) *PingPacketData {
	return &PingPacketData{
		Version: 4,

		From: from,
		To:   to,

		Expiration: uint64(time.Now().Add(20 * time.Second).Second()),

		ENRSequenceNumber: nil,
	}
}

func (p *PingPacketData) GetType() PacketType {
	return PACKET_TYPE_PING
}
