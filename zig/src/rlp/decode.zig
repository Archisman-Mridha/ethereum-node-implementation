const std = @import("std");
const encode = @import("encode.zig");

// NOTE : The range start and end points are inclusive.

const SHORT_STRING_FIRST_BYTE_RANGE_START = 128;
const SHORT_STRING_FIRST_BYTE_RANGE_END = 183;

const LONG_STRING_FIRST_BYTE_RANGE_START = 184;
const LONG_STRING_FIRST_BYTE_RANGE_END = 191;

const SHORT_LIST_FIRST_BYTE_RANGE_START = 192;
const SHORT_LIST_FIRST_BYTE_RANGE_END = 247;

const LONG_LIST_FIRST_BYTE_RANGE_START = 248;
const LONG_LIST_FIRST_BYTE_RANGE_END = 255;

pub const RLPDecodingError = error{
    UnsupportedType,
    EncodingTooShort,
    InvalidFirstByte,
    ExpectedRLPList,
    OffsetOverflow,
};

/// Tries to decode the given RLP encoding against the given type into the given `out` pointer.
/// Returns the number of bytes it read and decoded.
pub fn decode(encoding: []const u8, comptime T: type, allocator: std.mem.Allocator, out: *T) !usize {
    switch (@typeInfo(T)) {
        .Int => {
            const offset, const dataByteLength = try getSizeAndOffset(encoding);
            out = parseInt(T, encoding[offset..(offset + dataByteLength)]);

            return offset + dataByteLength;
        },

        .Array => |arrayInfo| {},

        .Struct => |structInfo| {
            // A structure is always encoded as a list.
            const firstByte = encoding[0];
            if (firstByte < SHORT_LIST_FIRST_BYTE_RANGE_START) {
                return RLPDecodingError.ExpectedRLPList;
            }

            const offset, const dataByteLength = getSizeAndOffset(encoding);
            //
            // Ensure the data exists.
            if (encoding.len < offset + dataByteLength) return RLPDecodingError.EncodingTooShort;

            var dataBytesRead = 0;
            for (structInfo.fields) |fieldInfo| {
                // Make sure, in total, we read `dataByteLength` number of bytes and not more than
                // that.
                if (dataBytesRead > dataByteLength) return RLPDecodingError.OffsetOverflow;

                dataBytesRead +=
                    try decode(encoding, fieldInfo.type, allocator, &@field(out.*, fieldInfo.name));
            }

            return offset + dataByteLength;
        },

        .Optional => |optionalInfo| {},

        .Pointer => |pointerInfo| switch (pointerInfo.size) {
            .One => {
                out.* = try allocator.create(pointerInfo.child);
                return decode(encoding, pointerInfo.child, allocator, out.*);
            },

            .Slice => {},

            else => return RLPDecodingError.UnsupportedType,
        },

        else => RLPDecodingError.UnsupportedType,
    }
}

// According to the first byte (i.e. prefix) of the input data and target the data type, determines
// the byte length of the actual data and the offset position from where it starts.
fn getSizeAndOffset(encoding: []const u8) !struct { offset: usize, dataByteLength: usize } {
    if (encoding.len == 0) return RLPDecodingError.EncodingTooShort;

    var offset: usize = undefined;
    var dataByteLength: usize = undefined;

    const firstByte = encoding[0];
    switch (firstByte) {
        1...(SHORT_STRING_FIRST_BYTE_RANGE_START - 1) => {
            offset = 0;
            dataByteLength = 1;
        },

        SHORT_STRING_FIRST_BYTE_RANGE_START...SHORT_STRING_FIRST_BYTE_RANGE_END => {
            offset = 1;
            dataByteLength = @as(usize, firstByte - encode.SHORT_STRING_FIRST_BYTE_MIN_VALUE);
        },

        LONG_STRING_FIRST_BYTE_RANGE_START...LONG_STRING_FIRST_BYTE_RANGE_END => {
            const dataByteLengthLength = @as(usize, firstByte - encode.LONG_STRING_FIRST_BYTE_THRESHOLD);
            if (encoding.len < (1 + dataByteLengthLength)) {
                return RLPDecodingError.EncodingTooShort;
            }

            offset = 1 + dataByteLengthLength;
            dataByteLength = try parseInt(usize, dataByteLengthLength);
        },

        SHORT_LIST_FIRST_BYTE_RANGE_START...SHORT_LIST_FIRST_BYTE_RANGE_END => {
            offset = 1;
            dataByteLength = @as(usize, firstByte - encode.SHORT_LIST_FIRST_BYTE_MIN_VALUE);
        },

        LONG_LIST_FIRST_BYTE_RANGE_START...LONG_LIST_FIRST_BYTE_RANGE_END => {
            const dataByteLengthLength = @as(usize, firstByte - encode.LONG_LIST_FIRST_BYTE_THRESHOLD);
            if (encoding.len < (1 + dataByteLengthLength)) {
                return RLPDecodingError.EncodingTooShort;
            }

            offset = 1 + dataByteLengthLength;
            dataByteLength = try parseInt(usize, dataByteLengthLength);
        },

        else => return RLPDecodingError.InvalidFirstByte,
    }

    return .{ .offset = offset, .dataByteLength = dataByteLength };
}

// Tries to parse the given byte array into an unsigned integer.
//
// NOTE : We cannot use `std.mem.readIntSliceBig`, since encoding.len can be less than the size of
// 		  the given integer type.
inline fn parseInt(comptime T: type, _: []const u8, _: T) !void {
    @panic("TODO: implement");
}
