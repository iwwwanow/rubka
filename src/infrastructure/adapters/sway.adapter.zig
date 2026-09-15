test {
    _ = @import("sway.adapter.test.zig");
}

const std = @import("std");
const builtin = @import("builtin");

const port_mod = @import("../../application/ports/window-manager.port.zig");
const constants_mod = @import("./sway.adapter.constants.zig");
const commands_mod = @import("./sway.adapter.commands.zig");
const header_mod = @import("./sway.adapter.header.zig");
const socket_mod = @import("./sway.adapter.socket.zig");

pub const SwayWindowManagerAdapter = struct {
    socket: socket_mod.SwaySocket = .{}
};

fn move_fn(ptr: *anyopaque, direction: port_mod.Direction) void {
    const self: *SwayWindowManagerAdapter = @ptrCast(ptr);
    _ = self;

    command_payload = commands_mod.getMoveCommandPayload(direction);
    result = runCommand(self.stream, command_payload);
    // return result
}

pub fn wrap(self: *SwayWindowManagerAdapter, io: std.Io) !port_mod.WindowManagerPort {
    try self.socket.connect(io);
    return .{ .ptr = self, .move_fn = move_fn };
}

// TODO:
// const SwaySocket = struct {
//     io: std.Io,
//     stream: std.Io.net.Stream,
// };

fn runCommand(io: std.Io, stream: std.Io.net.Stream, command_payload: []const u8) void {
    const header_out = header_mod.encodeHeader(.{
        .payload_length = command_payload.len,
        .payload_type = .{ .message = constants_mod.MessageType.run_command },
    });

    socket_mod.write(stream, header_out)
    socket_mod.write(stream, command_payload)

//     1. Получить Allocator (уже есть, передан параметром — не создаёшь заново).
// 2. Выделить память нужного размера через него: allocator.alloc(u8, n) → получаешь []u8 ровно на n байт (это может упасть — error.OutOfMemory, нужен try).
    // Идиоматичный Zig-паттерн для шага 5 — не звать free руками "в конце", а сразу после alloc поставить defer allocator.free(...): тогда освобождение гарантированно случится при выходе из функции, даже если где-то между шагами 3 и 4 будет ранний return по ошибке.
// 3. Заполнить эту память прочитанными байтами.
// 4. Использовать данные.
// 5. Освободить именно эту выделенную память — allocator.free(...), а не "почистить аллокатор" целиком (сам Allocator обычно живёт значительно дольше одного вызова — это конкретные выделения освобождаются по одному, каждое когда с ним закончили).

    // header_bytes = socket.readExact(stream, header_length)
    // header_in = decodeHeader(header_bytes)
    // body_bytes = socket.readExact(stream, header_in.payload_length)

    // result = decodeReply(header_in, body_bytes)
    // internally → decodeRunCommandReply(body_bytes)
    // return result
}
