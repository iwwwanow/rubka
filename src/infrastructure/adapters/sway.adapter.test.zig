const std = @import("std");
const builtin = @import("builtin");

const constants_mod = @import("./sway.adapter.constants.zig");
const adapter_mod = @import("./sway.adapter.zig");

const testing = std.testing;

// TODO: change to real payload;
const example_json = "{\"foo\":true}";
const endian = builtin.cpu.arch.endian();

var frame: [constants_mod.header_length + example_json.len]u8 = undefined;

test "decodeHeader: valid message frame" {
    @memcpy(frame[0..constants_mod.payload_magic_size], constants_mod.i3_ipc_magic);
    std.mem.writeInt(
        u32,
        frame[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size],
        example_json.len,
        endian,
    );

    std.mem.writeInt(
        u32,
        frame[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size],
        @intFromEnum(constants_mod.MessageType.get_version),
        endian,
    );

    @memcpy(frame[constants_mod.header_length..], example_json);

    const header = try adapter_mod.decodeHeader(&frame);
    try testing.expectEqual(@as(u32, example_json.len), header.payload_length);
    try testing.expectEqual(constants_mod.MessageType.get_version, header.payload_type.message);
}
