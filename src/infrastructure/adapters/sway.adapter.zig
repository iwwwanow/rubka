test {
    _ = @import("sway.adapter.test.zig");
}

const std = @import("std");
const builtin = @import("builtin");

const port_mod = @import("../../application/ports/window-manager.port.zig");
const constants_mod = @import("./sway.adapter.constants.zig");

pub const SwayWindowManagerAdapter = struct {};

fn move_fn(ptr: *anyopaque, direction: port_mod.Direction) void {
    const self: *SwayWindowManagerAdapter = @ptrCast(ptr);
    _ = self;

    // command_string = moveCommandString(direction)              // commands.zig
    // result = runCommand(self.stream, command_string)           // координатор, sway.adapter.zig
    // return result   // commandString() -> moveCommandString()
}

pub fn wrap(self: *SwayWindowManagerAdapter) port_mod.WindowManagerPort {
    return .{ .ptr = self, .move_fn = move_fn };
}

// runCommand(stream, command_string):
//     header_out = encodeHeader({                                // header.zig
//         payload_length: len(command_string),
//         payload_type: message.run_command
//     })
//
//     socket.write(stream, header_out)                           // socket.zig — сырые байты
//     socket.write(stream, command_string)                       // socket.zig — сырые байты
//
//     header_bytes = socket.readExact(stream, header_length)     // socket.zig
//     header_in = decodeHeader(header_bytes)                     // header.zig
//
//     body_bytes = socket.readExact(stream, header_in.payload_length)  // socket.zig
//
//     result = decodeReply(header_in, body_bytes)                // commands.zig
//   internally → decodeRunCommandReply(body_bytes)
// return result
