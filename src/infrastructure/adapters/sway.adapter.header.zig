const std = @import("std");
const builtin = @import("builtin");

const constants_mod = @import("./sway.adapter.constants.zig");

pub const Header = struct {
    payload_length: u32,
    payload_type: PayloadType,
};

const PayloadType = union(enum) {
    message: constants_mod.MessageType,
    event: constants_mod.EventType,
};

pub const FrameError = error{ InvalidMagic, BufferTooShort };

const endian = builtin.cpu.arch.endian();

pub fn decodeHeader(buf: []const u8) FrameError!Header {
    if (buf.len < constants_mod.header_length) return FrameError.BufferTooShort;
    const header_buf = buf[0..constants_mod.payload_magic_size];
    const is_i3_ipc_header = std.mem.eql(u8, header_buf, constants_mod.i3_ipc_magic);
    if (!is_i3_ipc_header) return FrameError.InvalidMagic;

    const payload_length_buf = buf[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size];
    const payload_length = std.mem.readInt(u32, payload_length_buf, endian);

    const payload_raw_type_buf = buf[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size];
    const payload_raw_type = std.mem.readInt(u32, payload_raw_type_buf, endian);

    const is_event = payload_raw_type & 0x80000000 != 0;
    const masked_type = payload_raw_type & 0x7FFFFFFF;

    const payload_type: PayloadType = if (is_event)
        PayloadType{ .event = @enumFromInt(masked_type) }
    else
        PayloadType{ .message = @enumFromInt(masked_type) };

    return Header{ .payload_length = payload_length, .payload_type = payload_type };
}

pub fn encodeHeader(header: Header) [constants_mod.header_length]u8 {
    var header_buf: [constants_mod.header_length]u8 = undefined;
    @memcpy(header_buf[0..constants_mod.payload_magic_size], constants_mod.i3_ipc_magic);
    std.mem.writeInt(
        u32,
        header_buf[constants_mod.payload_length_offset..][0..constants_mod.payload_length_size],
        header.payload_length,
        endian,
    );
    const payload_raw_type: u32 = switch (header.payload_type) {
        .message => |m| @intFromEnum(m),
        .event => |e| @intFromEnum(e) | 0x80000000,
    };
    std.mem.writeInt(
        u32,
        header_buf[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size],
        payload_raw_type,
        endian,
    );

    return header_buf;
}
