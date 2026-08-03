const port_mod = @import("../ports/window-manager.port.zig");

pub const MoveWindowUseCase = struct {
    window_manager: port_mod.WindowManagerPort,

    pub fn execute(self: MoveWindowUseCase, direction: port_mod.Direction) void {
        self.window_manager.move(direction);
    }
};
