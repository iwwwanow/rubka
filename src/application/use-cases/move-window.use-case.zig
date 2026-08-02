const window_manager_port = @import("../ports/window-manager.port.zig");

pub const MoveWindowUseCase = struct {
    windowManager: window_manager_port.Port,

    pub fn execute(self: MoveWindowUseCase, direction: window_manager_port.Direction) void {
        self.windowManager.move(direction);
    }
};
