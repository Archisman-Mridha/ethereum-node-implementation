const std = @import("std");

pub const RLPEncodingError = error{
    UnsupportedType,
};

// Recursive Length Prefix (RLP) serialization is used extensively in Ethereum's execution clients.
// RLP standardizes the transfer of data between nodes in a space-efficient format. The purpose of
// RLP is to encode arbitrarily nested arrays of binary data.
//
// With the exception of positive integers, RLP delegates encoding specific data types (e.g.
// strings, floats) to higher-order protocols.
//
// The RLP encoding function takes in an item. An item can be :
//		(1) a positive integer
// 		(2) a string (i.e. byte array)
//		(3) a list of items
pub fn encode(comptime T: type, data: T, encoding: *std.ArrayList(u8)) !void {
    const allocator = encoding.allocator;

    switch (@typeInfo(T)) {
        // Equivalent to an empty byte array.
        .Null => try encoding.append(0x80),

        .Int => switch (data) {
            // Positive integers must be represented in big-endian binary form with no leading
            // zeroes (thus making the integer value zero equivalent to the empty byte array).
            0 => try encoding.append(0x80),

            // For a positive integer, it is converted to the shortest byte array whose big-endian
            // interpretation is the integer, and then encoded as a string (i.e. byte array).

            // For a single byte whose value is in the 0 - 127 decimal range, that byte is its own
            // RLP encoding.
            1...127 => try encoding.append(@truncate(data)),

            // Otherwise, if a string is 0-55 bytes long, the RLP encoding consists of a single byte
            // with value 0x80 (128 in decimal) plus the length of the string followed by the string.
            // The decimal range of the first byte is thus 128 - 183.
            else => {
                var byteArray = std.ArrayList(u8).init(allocator);
                defer byteArray.deinit();

                try byteArray.writer().writeInt(T, data, .big);

                var startingPositionExcludingLeadingZeroes: usize = 0;
                while (byteArray[startingPositionExcludingLeadingZeroes] == 0) : (startingPositionExcludingLeadingZeroes += 1) {}

                try encoding.append(@as(u8, @truncate(128 + (byteArray.items.len - startingPositionExcludingLeadingZeroes))));
                try encoding.writer().write(byteArray.items[startingPositionExcludingLeadingZeroes..]);
            },
        },

        .Bool => try encoding.append(@as(u8, @intFromBool(data))),

        .Array => |arrayInfo| {
            var payload = std.ArrayList(u8).init(allocator);
            defer payload.deinit();

            for (data) |item| {
                try encode(arrayInfo.child, item, &payload);
            }

            try appendRLPEncodedPayload(payload, encoding);
        },

        // Equivalent to a list of items.
        // NOTE : Ordering of struct fields matters.
        .Struct => |structInfo| {
            var payload = std.ArrayList(u8).init(allocator);
            defer payload.deinit();

            for (structInfo.fields) |structField| {
                try encode(structField.type, @field(data, structField.name), &payload);
            }

            try appendRLPEncodedPayload(payload, encoding);
        },

        .Optional => |optionalInfo| {
            if (data == null) {
                encoding.append(0x80);
                return void;
            }

            try encode(optionalInfo.child, data.?, encoding);
        },

        .Pointer => |pointerInfo| {
            switch (pointerInfo.size) {
                .One => try encode(pointerInfo.child, data.*, encoding),

                // Represents a list of items.
                .Slice => {
                    var payload = std.ArrayList(u8).init(allocator);
                    defer payload.deinit();

                    for (data) |item| {
                        try encode(pointerInfo.child, item, &payload);
                    }

                    try appendRLPEncodedPayload(payload, encoding);
                },

                else => return RLPEncodingError.UnsupportedType,
            }
        },

        else => RLPEncodingError.UnsupportedType,
    }
}

fn appendRLPEncodedPayload(payload: *std.ArrayList(u8), encoding: *std.ArrayList(u8)) !void {
    // If the total payload of a list (i.e. the combined length of all its items being RLP
    // encoded) is 0-55 bytes long, the RLP encoding consists of a single byte with value
    // 0xc0 (192 in decimal) plus the length of the payload followed by the concatenation of
    // the RLP encodings of the items.
    // The decimal range of the first byte is thus 192 - 247.
    if (payload.items.len <= 55) {
        try encoding.append(@as(u8, @truncate(192 + payload.items.len)));
        try encoding.writer().write(payload.items);
    }

    // If the total payload of a list is more than 55 bytes long, the RLP encoding consists
    // of a single byte with value 0xf7 (247 in decimal) plus the length in bytes of the
    // length of the payload in binary form, followed by the length of the payload, followed
    // by the concatenation of the RLP encodings of the items.
    // The decimal range of the first byte is thus 248 - 255.
    else {
        var encodedPayloadLength: [8]u8 = undefined;
        std.mem.writeInt(usize, &encodedPayloadLength, payload.items.len, .big);
        const encodedPayloadLengthWithoutLeadingZeroes = std.mem.trimLeft(u8, &encodedPayloadLength, &[_]u8{0}); // Trim leading zeroes.

        const encodedPayloadLengthWithoutLeadingZeroesLength = @as(u8, encodedPayloadLengthWithoutLeadingZeroes.len);
        try encoding.append(@as(u8, @truncate(247 + encodedPayloadLengthWithoutLeadingZeroesLength)));

        try encoding.appendSlice(encodedPayloadLengthWithoutLeadingZeroes);

        try encoding.writer().write(payload.items);
    }
}
