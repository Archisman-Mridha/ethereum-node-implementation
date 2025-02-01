const std = @import("std");
const Hashes = @import("../../types/hashes.zig");

const BootNodeError = error{
    InvalidBootNodeEID,
};

// When a new node joins the Ethereum network it needs to connect to nodes that are already on the
// network in order to then discover new peers. These entry points into the Ethereum network are
// called bootnodes.
//
// Bootnodes are full nodes that are not behind a NAT (Network Address Translation).
//
// Clients usually have a list of bootnodes hardcoded into them. These bootnodes are typically run
// by the Ethereum Foundation's devops team or client teams themselves.
//
// NOTE : Bootnodes are not the same as static nodes. Static nodes are called over and over again,
//        whereas bootnodes are only called upon if there are not enough peers to connect to and a
//        node needs to bootstrap some new connections.
pub const BootNode = struct {
    node_id: Hashes.H512,
    socket_address: std.net.Ip4Address,

    // Parses the given enode into a BootNode struct.
    pub fn from_string(enode: []const u8) !BootNode {
        if (!std.mem.startsWith(u8, enode, "enode://")) {
            return BootNodeError.InvalidBootNodeEID;
        }

        const hex_encoded_node_id = enode[8..136];

        var node_id: Hashes.H512 = undefined;
        _ = try std.fmt.hexToBytes(&node_id, hex_encoded_node_id);

        const encoded_socket_address = enode[137..];
        const socket_address = try parse_socket_address(encoded_socket_address);

        return BootNode{
            .node_id = node_id,
            .socket_address = socket_address,
        };
    }
};

// Parses the given encoded socket address.
// TODO : Support IPv6 address.
pub fn parse_socket_address(encoded_socket_address: []const u8) !std.net.Address {
    var iterator = std.mem.splitScalar(u8, encoded_socket_address, ':');

    const ip_address = iterator.next().?;
    const port = try std.fmt.parseInt(u16, iterator.next().?, 10);
    if (iterator.next() != null) {
        return std.net.IPParseError;
    }

    const ipv4_address = try std.net.Ip4Address.parse(ip_address, port);

    return std.net.Address{ .in = ipv4_address };
}

test "parse valid enode" {
    const enode =
        "enode://d860a01f9722d78051619d1e2351aba3f43f943f6f00718d1b9baa4101932a1f5011f16bb2b1bb35db20d6fe28fa0bf09636d26a87d31de9ec6203eeedb1f666@18.138.108.67:30303";

    _ = try BootNode.from_string(enode);
}

test "parse valid socket address" {
    const encoded_socket_address = "8.138.108.67:30303";
    _ = try parse_socket_address(encoded_socket_address);
}
