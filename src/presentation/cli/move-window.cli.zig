const use_case_mod = @import("../../application/use-cases/move-window.use-case.zig");

pub const MoveWindowCli = struct {
    move_window_use_case: use_case_mod.MoveWindowUseCase,

    // TODO: catch error on what level?
    pub fn left(self: MoveWindowCli) void {
        self.move_window_use_case.execute(.left);
    }

    pub fn right(self: MoveWindowCli) void {
        self.move_window_use_case.execute(.right);
    }
};
