const std = @import("std");
const os = std.os;
const BootNode = @import("./bootnode.zig").BootNode;

// Ethereum is a peer-to-peer network with thousands of nodes that must be able to communicate with
// one another using standardized protocols.
//
// There are two parts to the client software (execution clients and consensus clients), each with
// its own distinct networking stack.
//
// The execution layer's networking protocols is divided into two stacks : the Discovery stack and
// the DevP2P stack.
pub const NetworkStack = struct {
    pub const StartNetworkStackArgs = struct {
        bootNodes: []const BootNode,
    };

    pub fn start() !void {
        std.debug.print("Starting execution client networking stack", .{});
    }

    // Built on top of UDP and allows a new node to find peers to connect to.
    pub const DiscoveryStack = struct {
        pub fn start(socket_address: std.posix.sockaddr.in) !void {
            const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.CLOEXEC, 0);
            try std.posix.bind(socket, @ptrCast(&socket_address), @sizeOf(@TypeOf(socket_address)));

            while (true) {}
        }
    };

    // Sits on top of TCP and enables nodes to exchange information.
    pub const DevP2PStack = struct {};
};
