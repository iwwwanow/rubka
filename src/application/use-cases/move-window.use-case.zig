const window_manager_port = @import("../ports/window-manager.port.zig");

pub const MoveWindowUseCase = struct {
    window_manager: window_manager_port.Port,

    pub fn execute(self: MoveWindowUseCase, direction: window_manager_port.Direction) void {
        self.window_manager.move(direction);
    }
};
