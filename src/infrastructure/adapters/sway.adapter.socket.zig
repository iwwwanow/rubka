// TODO: изолировать от sway. системная штука, свободная от вендора

const std = @import("std");

// write(stream, bytes)
// readExact(stream, n) -> bytes

// TODO: write errors on return
pub fn write(io: std.Io, stream: std.Io.net.Stream, data: []const u8) !void {}
