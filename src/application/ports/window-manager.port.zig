// TODO: extend it
pub const Direction = enum { left, right };

pub const WindowManagerPort = struct {
    ptr: *anyopaque,
    move_fn: *const fn (ptr: *anyopaque, direction: Direction) void,

    pub fn move(self: WindowManagerPort, direction: Direction) void {
        self.move_fn(self.ptr, direction);
    }
};
