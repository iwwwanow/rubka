// TODO: extend it
pub const Direction = enum { left, right };

pub const Port = struct {
    ptr: *anyopaque,
    moveFn: *const fn (ptr: *anyopaque, direction: Direction) void,

    pub fn move(self: Port, direction: Direction) void {
        self.moveFn(self.ptr, direction);
    }
};
