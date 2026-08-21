const std = @import("std");
const builtin = @import("builtin");

const constants_mod = @import("./sway.adapter.constants.zig");
const adapter_mod = @import("./sway.adapter.zig");

const testing = std.testing;

// TODO: change to real payload;
const example_json = "{\"foo\":true}";
const endian = builtin.cpu.arch.endian();

test "decodeHeader: valid message frame" {
    var message_frame: [constants_mod.header_length + example_json.len]u8 = undefined;
    @memcpy(message_frame[0..constants_mod.payload_magic_size], constants_mod.i3_ipc_magic);
    std.mem.writeInt(
        u32,
        message_frame[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size],
        example_json.len,
        endian,
    );

    std.mem.writeInt(
        u32,
        message_frame[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size],
        @intFromEnum(constants_mod.MessageType.get_version),
        endian,
    );

    @memcpy(message_frame[constants_mod.header_length..], example_json);

    const header = try adapter_mod.decodeHeader(&message_frame);
    try testing.expectEqual(@as(u32, example_json.len), header.payload_length);
    try testing.expectEqual(constants_mod.MessageType.get_version, header.payload_type.message);
}

test "decodeHeader: valid event frame" {
    var event_frame: [constants_mod.header_length + example_json.len]u8 = undefined;
    @memcpy(event_frame[0..constants_mod.payload_magic_size], constants_mod.i3_ipc_magic);
    std.mem.writeInt(
        u32,
        event_frame[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size],
        example_json.len,
        endian,
    );
    std.mem.writeInt(
        u32,
        event_frame[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size],
        @intFromEnum(constants_mod.EventType.window) | 0x80000000,
        endian,
    );
    @memcpy(event_frame[constants_mod.header_length..], example_json);

    const header = try adapter_mod.decodeHeader(&event_frame);
    try testing.expectEqual(@as(u32, example_json.len), header.payload_length);
    try testing.expectEqual(constants_mod.EventType.window, header.payload_type.event);
}

test "decodeHeader: buffer too short" {
    var short_buf: [constants_mod.header_length - 1]u8 = undefined;
    try testing.expectError(adapter_mod.FrameError.BufferTooShort, adapter_mod.decodeHeader(&short_buf));
}

test "decodeHeader: invalid magic" {
    var invalid_magic_buf: [constants_mod.header_length]u8 = undefined;
    @memcpy(invalid_magic_buf[0..constants_mod.payload_magic_size], "i4-ipc");
    try testing.expectError(adapter_mod.FrameError.InvalidMagic, adapter_mod.decodeHeader(&invalid_magic_buf));
}

test "encodeHeader: valid message frame" {
    const header: adapter_mod.Header = .{ .payload_length = example_json.len, .payload_type = .{ .message = constants_mod.MessageType.get_version } };
    const message_frame: [constants_mod.header_length]u8 = adapter_mod.encodeHeader(header);

    try testing.expectEqualSlices(u8, constants_mod.i3_ipc_magic, message_frame[0..constants_mod.payload_magic_size]);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&header.payload_length), message_frame[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size]);
    const decoded_raw_type = std.mem.readInt(u32, message_frame[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size], endian);
    try testing.expectEqual(@intFromEnum(header.payload_type.message), decoded_raw_type);
}

test "encodeHeader: valid event frame" {
    const header: adapter_mod.Header = .{ .payload_length = example_json.len, .payload_type = .{ .event = constants_mod.EventType.window } };
    const event_frame: [constants_mod.header_length]u8 = adapter_mod.encodeHeader(header);

    try testing.expectEqualSlices(u8, constants_mod.i3_ipc_magic, event_frame[0..constants_mod.payload_magic_size]);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&header.payload_length), event_frame[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size]);
    const decoded_raw_type = std.mem.readInt(u32, event_frame[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size], endian);
    try testing.expectEqual(@intFromEnum(header.payload_type.event) | 0x80000000, decoded_raw_type);
}

// INFO: regression guard
test "encodeHeader: payload_length zero" {
    const header: adapter_mod.Header = .{ .payload_length = 0, .payload_type = .{ .event = constants_mod.EventType.window } };
    const frame: [constants_mod.header_length]u8 = adapter_mod.encodeHeader(header);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&header.payload_length), frame[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size]);
}

// INFO: regression guard
test "encodeHeader: payload_length max u32" {
    const header: adapter_mod.Header = .{ .payload_length = std.math.maxInt(u32), .payload_type = .{ .event = constants_mod.EventType.window } };
    const frame: [constants_mod.header_length]u8 = adapter_mod.encodeHeader(header);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&header.payload_length), frame[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size]);
}

test "encodeHeader: non-exhaustive enum value" {
    const non_exhaustive_value: u32 = 9999;
    const header: adapter_mod.Header = .{ .payload_length = example_json.len, .payload_type = .{ .message = @enumFromInt(non_exhaustive_value) } };
    const frame: [constants_mod.header_length]u8 = adapter_mod.encodeHeader(header);
    const decoded_raw_type = std.mem.readInt(u32, frame[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size], endian);
    try testing.expectEqual(non_exhaustive_value, decoded_raw_type);
}

test "round trip" {
    const header: adapter_mod.Header = .{ .payload_length = 0, .payload_type = .{ .event = constants_mod.EventType.window } };
    const encoded_header_frame: [constants_mod.header_length]u8 = adapter_mod.encodeHeader(header);
    const decoded_header = try adapter_mod.decodeHeader(&encoded_header_frame);
    try testing.expectEqual(header, decoded_header);
}
