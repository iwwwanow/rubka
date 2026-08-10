test {
    _ = @import("sway.adapter.test.zig");
}

const std = @import("std");

const constants_mod = @import("./sway.adapter.constants.zig");

const Header = struct {
    payload_length: u32,
    payload_type: PayloadType,
};

const PayloadType = union(enum) {
    message: constants_mod.MessageType,
    event: constants_mod.EventType,
};

pub const FrameError = error{ InvalidMagic, BufferTooShort };

pub fn decodeHeader(buf: []const u8) FrameError!Header {
    // TODO: length check
    const is_i3_ipc_header = std.mem.eql(u8, buf[0..6], constants_mod.i3_ipc_magic);
    if (!is_i3_ipc_header) return FrameError.InvalidMagic;
}
