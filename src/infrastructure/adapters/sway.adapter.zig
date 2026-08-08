const std = @import("std");

test {
    _ = @import("sway.adapter.test.zig");
}

const Header = struct {
    payload_length: u32,
    payload_type: PayloadType,
};

const PayloadType = union(enum) {
    message: MessageType,
    event: EventType,
};

const MessageType = enum(u32) {};
const EventType = enum(u32) {};

pub const FrameError = error{ InvalidMagic, BufferTooShort };

pub fn decodeHeader(buf: []const u8) FrameError!Header {
    // TODO: length check
    // TODO: magic to const
    const is_i3_ipc_header = std.mem.eql(u8, buf[0..6], "i3-ipc");
    if (!is_i3_ipc_header) return FrameError.InvalidMagic;
}
