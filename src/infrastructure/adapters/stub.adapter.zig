const std = @import("std");

const port_mod = @import("../../application/ports/window-manager.port.zig");

pub const StubWindowManagerAdapter = struct {};

fn move_fn(ptr: *anyopaque, direction: port_mod.Direction) void {
    const self: *StubWindowManagerAdapter = @ptrCast(ptr);
    _ = self;

    const direction_string: [:0]const u8 = @tagName(direction);
    std.debug.print("stub adapter works with direction: {s}\n", .{direction_string});
}

pub fn wrap(self: *StubWindowManagerAdapter) port_mod.WindowManagerPort {
    return .{ .ptr = self, .move_fn = move_fn };
}
