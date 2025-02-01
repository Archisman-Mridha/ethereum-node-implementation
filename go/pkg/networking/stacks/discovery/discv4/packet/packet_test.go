package packet

import (
	"context"
	"encoding/hex"
	"log/slog"
	"net/netip"
	"testing"

	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/assert"
)

func TestPacketDataRLPEncode(t *testing.T) {
	pingPacketData := NewPingPacketData(
		NewEndpointFromSocketAddress(netip.MustParseAddrPort("0.0.0.0:30303")),
		NewEndpointFromSocketAddress(netip.MustParseAddrPort("51.15.116.226:30303")),
	)

	privateKey, err := crypto.GenerateKey()
	assert.Nil(t, err)

	_, encodedPacket, err := NewPacket(pingPacketData, privateKey)
	assert.Nil(t, err)

	assert.Greater(t, len(encodedPacket), PACKET_HEADER_SIZE)
}

func TestPingPacketRLPDecode(t *testing.T) {
	encodedPacket, err := hex.DecodeString(
		"a446009d9c148e1695ad3f6f02311861cee623569b707e7ffbd60bc4443cc860b4c2beef26bae5f349c2ba6d7fdaf960b6f663fd726ec56bad9600a46ba6e6317a7fb24c411cb71b63ec52f3b15c868730ee6d07b1944d1a3c104d1f842b58340101d304c7c082765f82765fc7c082765f82765f1080",
	)
	assert.Nil(t, err)

	pingPacket, err := DecodeRLP(encodedPacket)
	assert.Nil(t, err)

	slog.InfoContext(context.Background(), "RLP decoded ping packet", slog.Any("packet", pingPacket))
}
