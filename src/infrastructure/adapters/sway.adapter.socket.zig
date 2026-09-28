// TODO: изолировать от sway. системная штука, свободная от вендора

const std = @import("std");

// write(stream, bytes)
// readExact(stream, n) -> bytes

pub const SwaySocket = struct {
    reader: std.Io.net.Stream.Reader = undefined,
    writer: std.Io.net.Stream.Writer = undefined,
    read_buf: [4096]u8 = undefined,
    write_buf: [4096]u8 = undefined,

    pub fn connect(self: *SwaySocket, io: std.Io, path: []const u8) !void {
        const stream_path = try std.Io.net.UnixAddress.init(path);
        const stream = try stream_path.connect(io);

        self.reader = std.Io.net.Stream.Reader.init(stream, io, &self.read_buf);
        self.writer = std.Io.net.Stream.Writer.init(stream, io, &self.write_buf);
    }

    pub fn readInto(self: *SwaySocket, buffer: []u8) !void {
        try self.reader.interface.readSliceAll(buffer);
    }

    pub fn write(self: *SwaySocket, bytes: []const u8) !void {
        try self.writer.interface.writeAll(bytes);
        // INFO: заголовок и тело будут уходить в сокет отдельными кусками.
        // проблемы в этом нет, потомучто сокет читает из потока, но нужно иметь в виду.
        // в будующем можно вынести flush внаружу и вызывать на более верхнем уровне
        try self.writer.interface.flush();
    }

    // TODO: pub fn close() {};
};
