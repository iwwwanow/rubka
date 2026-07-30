const std = @import("std");
const Io = std.Io;

pub fn printHelloWorld() void {
    std.log.info("Hello World!", .{});
}
