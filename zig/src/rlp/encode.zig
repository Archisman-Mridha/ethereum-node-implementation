const std = @import("std");

const BYTE_REPRESENTING_EMPTY_BYTE_ARRAY = 0x80;

const SHORT_STRING_FIRST_BYTE_MIN_VALUE = 127;
const LONG_STRING_FIRST_BYTE_THRESHOLD = 183;

const SHORT_LIST_FIRST_BYTE_MIN_VALUE = 191;
const LONG_LIST_FIRST_BYTE_THRESHOLD = 247;

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
//
/// Tries to encode the given data into the given buffer.
pub fn encode(comptime T: type, data: T, encoding: *std.ArrayList(u8)) !void {
    const allocator = encoding.allocator;

    switch (@typeInfo(T)) {
        // Considered as an empty byte array.
        .Null => try encoding.append(0x80),

        .Int => switch (data) {
            // Positive integers must be represented in big-endian binary form with no leading
            // zeroes (thus making the integer value zero equivalent to an empty byte array).
            0 => try encoding.append(0x80),

            // For a positive integer, it is converted to the shortest byte array whose big-endian
            // interpretation is the integer, and then encoded as a string (i.e. byte array).

            // For a single byte whose value is in the 0 - 127 decimal range, that byte is its own
            // RLP encoding.
            1...127 => try encoding.append(@truncate(data)),

            // Considered as a short string.
            else => {
                var byteArray = std.ArrayList(u8).init(allocator);
                defer byteArray.deinit();

                try byteArray.writer().writeInt(T, data, .big);

                var startingPositionExcludingLeadingZeroes: usize = 0;
                while (byteArray[startingPositionExcludingLeadingZeroes] == 0) : (startingPositionExcludingLeadingZeroes += 1) {}

                try encodeString(byteArray[startingPositionExcludingLeadingZeroes..], encoding);
            },
        },

        .Bool => try encoding.append(@as(u8, @intFromBool(data))),

        .Array => |arrayInfo| {
            // Considered as a string.
            if ((@sizeOf(arrayInfo.child) == 1)) {
                switch (data.len) {
                    // Considered as an empty string.
                    0 => try encoding.append(0x80),

                    // Consider as an integer.
                    1 => try encode(arrayInfo.child, data[0], encoding),

                    // Considered as a short string.
                    2...55 => try encodeString(data, encoding),

                    // Considered as a long string.
                    else => try encodeString(data, encoding),
                }
            }

            // Considered as a list.
            else {
                var payload = std.ArrayList(u8).init(allocator);
                defer payload.deinit();

                for (data) |item| {
                    try encode(arrayInfo.child, item, &payload);
                }

                try encodeListPayload(payload, encoding);
            }
        },

        // Considered as a list of items.
        // NOTE : Ordering of struct fields matters.
        .Struct => |structInfo| {
            var payload = std.ArrayList(u8).init(allocator);
            defer payload.deinit();

            for (structInfo.fields) |structField| {
                try encode(structField.type, @field(data, structField.name), &payload);
            }

            try encodeListPayload(payload, encoding);
        },

        .Optional => |optionalInfo| {
            // Considered as an empty byte array.
            if (data == null) {
                encoding.append(0x80);
                return void;
            }

            try encode(optionalInfo.child, data.?, encoding);
        },

        .Pointer => |pointerInfo| switch (pointerInfo.size) {
            .One => try encode(pointerInfo.child, data.*, encoding),

            .Slice => {
                // Considered as a string.
                if (@sizeOf(pointerInfo.child) == 1) {
                    switch (data.len) {
                        // Considered as an empty string.
                        0 => try encoding.append(0x80),

                        // Consider as an integer.
                        1 => try encode(pointerInfo.child, data[0], encoding),

                        // Considered as a short string.
                        2...55 => try encodeString(data, encoding),

                        // Considered as a long string.
                        else => try encodeString(data, encoding),
                    }
                }

                // Considered as a list.
                else {
                    var payload = std.ArrayList(u8).init(allocator);
                    defer payload.deinit();

                    for (data) |item| {
                        try encode(pointerInfo.child, item, &payload);
                    }

                    try encodeListPayload(payload, encoding);
                }
            },

            else => return RLPEncodingError.UnsupportedType,
        },

        else => RLPEncodingError.UnsupportedType,
    }
}

fn encodeString(string: []const u8, encoding: *std.ArrayList(u8)) !void {
    // Handling short string :
    // If a string is 0-55 bytes long, the RLP encoding consists of a single byte
    // with value 0x80 (128 in decimal) plus the length of the string followed by the string.
    // The decimal range of the first byte is thus 128 - 183.
    if (string.len <= 55) {
        try encoding.append(@as(u8, @truncate(SHORT_STRING_FIRST_BYTE_MIN_VALUE + string.len)));
        try encoding.writer().write(string.items);
    }

    // Handling long string :
    // If a string is more than 55 bytes long, the RLP encoding consists of a single byte with value
    // 0xb7 (183 in decimal) plus the length in bytes of the length of the string in binary form,
    // followed by the length of the string, followed by the string.
    // The decimal range of the first byte is thus 184 - 191.
    else {
        var stringLength: [8]u8 = undefined;
        std.mem.writeInt(usize, &stringLength, string.len, .big);
        const stringLengthWithoutLeadingZeroes = std.mem.trimLeft(u8, &stringLength, &[_]u8{0}); // Trim leading zeroes.

        const stringLengthWithoutLeadingZeroesLength = @as(u8, stringLengthWithoutLeadingZeroes.len);
        try encoding.append(@as(u8, @truncate(LONG_STRING_FIRST_BYTE_THRESHOLD + stringLengthWithoutLeadingZeroesLength)));

        try encoding.appendSlice(stringLengthWithoutLeadingZeroes);

        try encoding.writer().write(string);
    }
}

fn encodeListPayload(payload: *std.ArrayList(u8), encoding: *std.ArrayList(u8)) !void {
    // Handling short list :
    // If the total payload of a list (i.e. the combined length of all its items being RLP
    // encoded) is 0-55 bytes long, the RLP encoding consists of a single byte with value
    // 0xc0 (192 in decimal) plus the length of the payload followed by the concatenation of
    // the RLP encodings of the items.
    // The decimal range of the first byte is thus 192 - 247.
    if (payload.items.len <= 55) {
        try encoding.append(@as(u8, @truncate(SHORT_LIST_FIRST_BYTE_MIN_VALUE + payload.items.len)));
        try encoding.writer().write(payload.items);
        return void;
    }

    // Handling long list :
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
        try encoding.append(@as(u8, @truncate(LONG_LIST_FIRST_BYTE_THRESHOLD + encodedPayloadLengthWithoutLeadingZeroesLength)));

        try encoding.appendSlice(encodedPayloadLengthWithoutLeadingZeroes);

        try encoding.writer().write(payload.items);
    }
}
