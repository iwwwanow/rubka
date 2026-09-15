// TODO: изолировать от sway. системная штука, свободная от вендора

const std = @import("std");

// write(stream, bytes)
// readExact(stream, n) -> bytes

pub const SwaySocket = struct {
    reader: std.Io.net.Stream.Reader,
    writer: std.Io.net.Stream.Writer,
    read_buf: [4096]u8 = undefined,
    write_buf: [4096]u8 = undefined,

    pub fn connect(self: SwaySocket, io: std.Io, path: []const u8) void {
        const stream = std.Io.net.UnixAddress.init(path);

        self.reader.init(stream, io, read_buf);
        self.writer.init(stream, io, write_buf);
    };

    pub fn readInto() {

    };

    pub fn write() {

    };

    // TODO: pub fn close() {};
};

// TODO: write errors on return
pub fn write(io: std.Io, stream: std.Io.net.Stream, data: []const u8) !void {}

// INFO: struct for params?
// Твой // INFO: struct for params? — по делу: теперь у функции 4 параметра, из которых 3 (io, stream, allocator) — это не данные конкретного вызова, а "возможности"/контекст, который будет одинаков почти при каждом вызове в этом файле. Ровно та же логика, что с SwaySocket{io, stream} — сюда напрашивается allocator туда же, в один общий контекст-параметр, а bytes_length остаётся единственным реальным per-call аргументом. Само разделение "контекст vs данные вызова" — правильный сигнал, а как назвать структуру и что в неё класть (просто добавить allocator в SwaySocket, или сделать отдельную) — уже твоё архитектурное решение.
pub fn readInto(io: std.Io, stream: std.Io.net.Stream, buffer: []u8) ![]const u8 {}
