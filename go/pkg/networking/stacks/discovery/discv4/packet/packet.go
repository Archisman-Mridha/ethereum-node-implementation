package packet

import (
	"crypto/ecdsa"
	"errors"
	"fmt"

	"github.com/ethereum/go-ethereum/rlp"
)

const (
	PACKET_TYPE_PING = iota + 1
	PACKET_TYPE_PONG
)

type (
	Packet struct {
		Header *PacketHeader
		Data   PacketData
	}

	PacketType = byte

	PacketData interface {
		GetType() PacketType
	}
)

func NewPacket(packetData PacketData, nodePrivateKey *ecdsa.PrivateKey) (*Packet, []byte, error) {
	packetHeader, encodedPacket, err := newPacketHeader(packetData, nodePrivateKey)
	if err != nil {
		return nil, nil, fmt.Errorf("couldn't construct packet header : %v", err)
	}

	packet := &Packet{
		Header: packetHeader,
		Data:   packetData,
	}
	return packet, encodedPacket, nil
}

func DecodeRLP(encodedPacket []byte) (*Packet, error) {
	packet := new(Packet)

	encodedPacketHeader := encodedPacket[:PACKET_HEADER_SIZE]
	packetHeader := new(PacketHeader)
	if err := rlp.DecodeBytes(encodedPacketHeader, packetHeader); err != nil {
		return nil, fmt.Errorf("couldn't RLP decode packet header : %v", err)
	}
	packet.Header = packetHeader

	encodedPacketData := encodedPacket[PACKET_HEADER_SIZE:]

	switch packetHeader.Type {
	case PACKET_TYPE_PING:
		pingPacketData := new(PingPacketData)
		if err := rlp.DecodeBytes(encodedPacketData, pingPacketData); err != nil {
			return nil, fmt.Errorf("couldn't RLP decode ping packet data : %v", err)
		}
		packet.Data = pingPacketData

	case PACKET_TYPE_PONG:
		pongPacketData := new(PongPacketData)
		if err := rlp.DecodeBytes(encodedPacketData, pongPacketData); err != nil {
			return nil, fmt.Errorf("couldn't RLP decode pong packet data : %v", err)
		}
		packet.Data = pongPacketData

	default:
		return nil, errors.New("couldn't RLP decode packet data : invalid packet type")
	}

	return packet, nil
}
