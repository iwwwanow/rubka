test {
    _ = @import("sway.adapter.test.zig");
}

const std = @import("std");
const builtin = @import("builtin");

const port_mod = @import("../../application/ports/window-manager.port.zig");
const constants_mod = @import("./sway.adapter.constants.zig");
const commands_mod = @import("./sway.adapter.commands.zig");
const header_mod = @import("./sway.adapter.header.zig");
const socket_mod = @import("./sway.adapter.socket.zig");

pub const SwayWindowManagerAdapter = struct {};

fn move_fn(ptr: *anyopaque, direction: port_mod.Direction) void {
    const self: *SwayWindowManagerAdapter = @ptrCast(ptr);
    _ = self;

    command_payload = commands_mod.getMoveCommandPayload(direction);
    result = runCommand(self.stream, command_payload);
    // return result
}

pub fn wrap(self: *SwayWindowManagerAdapter) port_mod.WindowManagerPort {
    return .{ .ptr = self, .move_fn = move_fn };
}

// TODO: 
// const SwaySocket = struct {
//     io: std.Io,
//     stream: std.Io.net.Stream,
// };

fn runCommand(io: std.Io, stream: std.Io.net.Stream, command_payload: []const u8) {
    const header_out = header_mod.encodeHeader({
        payload_length: len(command_string),
        payload_type: .{ .message = constants_mod.Message.run_command}
    })

    socket_mod.write(stream, header_out)
    // INFO: why we write command string?
    socket_mod.write(stream, command_payload)

// header_bytes = socket.readExact(stream, header_length)
// header_in = decodeHeader(header_bytes)
// body_bytes = socket.readExact(stream, header_in.payload_length)

// result = decodeReply(header_in, body_bytes)
// internally → decodeRunCommandReply(body_bytes)
// return result
}

