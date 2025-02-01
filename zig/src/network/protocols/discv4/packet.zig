const std = @import("std");
const sha3 = @import("std").crypto.hash.sha3;
pub const Hashes = @import("../../../types/hashes.zig");

const PacketError = error{
    InvalidPacketSize,
    InvalidPacketHash,
    InvalidPacketType,
};

// Node discovery messages are sent as UDP datagrams.
pub const Packet = struct {
    const SELF = @This();

    header: PacketHeader,
    data: PacketData,

    pub fn decode(encoded_packet: []const u8) !SELF {
        if (encoded_packet.len < PacketHeader.SIZE) {
            return PacketError.InvalidPacketSize;
        }

        const encoded_packet_header = encoded_packet[0..PacketHeader.SIZE];
        const packet_header: *const PacketHeader = @ptrCast(encoded_packet_header);

        // Verify that the packet hash is valid.
        {
            var expected_packet_hash: Hashes.H256 = undefined;
            sha3.Keccak256.hash(encoded_packet[@sizeOf(Hashes.H256)..], &expected_packet_hash);

            if (!std.mem.eql(u8, packet_header.hash, expected_packet_hash)) {
                return PacketError.InvalidPacketHash;
            }
        }

        const encoded_packet_data = encoded_packet[PacketHeader.SIZE..];
        PacketData.decode(packet_header.type, encoded_packet_data);
    }
};

pub const PacketHeader = packed struct {
    const SELF = @This();
    const SIZE = @sizeOf(SELF);

    // Exists to make the packet format recognizable when running multiple protocols on the same
    // UDP port. It serves no other purpose.
    hash: Hashes.H256,

    // Every packet is signed by the node's identity key.
    // This represents that ECDSA signature.
    signature: Hashes.H520,

    // Defines the type of the packet / message.
    type: u8,
};

pub const PacketData = union(enum) {
    const SELF = @This();

    ping: *const PingPacketData,
    pong: *const PongPacketData,

    find_node: *const FindNodePacketData,

    neighbours: *const NeighboursPacketData,

    enrRequest: *const ENRRequestPacketData,
    enrResponse: *const ENRResponsePacketData,

    pub fn decode(packet_type: u8, encoded_packet_data: []const u8) !SELF {
        return switch (packet_type) {
            0x01 => PacketData{ .ping = @ptrCast(encoded_packet_data) },

            0x02 => PacketData{ .pong = @ptrCast(encoded_packet_data) },

            0x03 => PacketData{ .find_node = @ptrCast(encoded_packet_data) },

            0x04 => PacketData{ .neighbours = @ptrCast(encoded_packet_data) },

            0x05 => PacketData{ .enrRequest = @ptrCast(encoded_packet_data) },

            0x06 => PacketData{ .enrResponse = @ptrCast(encoded_packet_data) },

            _ => return PacketError.InvalidPacketType,
        };
    }
};

// When a Ping type packet is received, the recipient should reply with a Pong type packet. It may
// also consider the sender for addition into the local table.
//
// If no communication with the sender has occurred within the last 12h, a ping should be sent in
// addition to pong in order to receive an endpoint proof.
//
// Packets that mismatch the discovery protocol version we're using, will be ignored.
pub const PingPacketData = packed struct {
    // The Discovery protocol version the message sender is using.
    // Must be set to 4.
    version: u8,

    from: Endpoint,
    to: Endpoint,

    // An absolute UNIX time stamp.
    // Expired packets will not be processed.
    expiration: u64,

    // ENR sequence number of the sender.
    enr_sequence_number: ?u64,
};

// Pong type packet is the reply to a Ping type packet.
// We will ignore unsolicited Pong type packets that do not contain the hash of the most recent
// corresponding Ping type packet (if it was sent).
pub const PongPacketData = packed struct {
    to: Endpoint,

    // Hash of the corresponding Ping type packet.
    ping_hash: Hashes.H256,

    // An absolute UNIX time stamp.
    // Expired packets will not be processed.
    expiration: u64,

    // ENR sequence number of the sender.
    enr_sequence_number: ?u64,
};

pub const FindNodePacketData = packed struct {};

pub const NeighboursPacketData = packed struct {};

pub const ENRRequestPacketData = packed struct {};

pub const ENRResponsePacketData = packed struct {};

pub const Endpoint = packed struct {
    ip_address: std.net.Ip4Address,
    udp_port: u16,
    tcp_port: u16,
};
