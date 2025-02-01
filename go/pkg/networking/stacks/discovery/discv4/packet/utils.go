package packet

import (
	"net/netip"
)

type Endpoint struct {
	IPAddress netip.Addr

	UDPPort,
	TCPPort uint16
}

func NewEndpointFromSocketAddress(socketAddress netip.AddrPort) *Endpoint {
	return &Endpoint{
		IPAddress: socketAddress.Addr(),

		// BUG : The UDP and TCP ports can be different.
		UDPPort: socketAddress.Port(),
		TCPPort: socketAddress.Port(),
	}
}
