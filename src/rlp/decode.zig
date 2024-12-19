const std = @import("std");

pub const RLPDecodingError = error{};

pub fn decode(encoding: *std.ArrayList(u8), comptime T: type, allocator: std.mem.Allocator) !void {}
