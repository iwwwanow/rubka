const port_mod = @import("../../application/ports/window-manager.port.zig");

const Command = struct {
    const move_left = "move left";
    const move_right = "move right";
};

pub fn getMoveCommandPayload(direction: port_mod.Direction) []const u8 {
    return switch (direction) {
        .left => Command.move_left,
        .right => Command.move_right,
    };
}
