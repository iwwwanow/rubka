// TODO: extend it
const Direction = enum { left, right };

pub const WindowManagerPort = struct {
    ptr: *anyopaque,
    moveFn: *const fn (ptr: *anyopaque, direction: Direction) void,

    fn move(self: WindowManagerPort, direction: Direction) void {
        self.moveFn(self.ptr, direction);
    }
};
