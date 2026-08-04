const std = @import("std");
const Io = std.Io;

const adapter_mod = @import("./infrastructure/adapters/stub.adapter.zig");
const use_case_mod = @import("./application/use-cases/move-window.use-case.zig");

const iwwwanow_rubka = @import("iwwwanow_rubka");

pub fn main() void {
    var adapter_impl: adapter_mod.StubWindowManagerAdapter = .{};
    const port_impl = adapter_mod.wrap(&adapter_impl);
    const use_case_impl: use_case_mod.MoveWindowUseCase = .{ .window_manager = port_impl };

    iwwwanow_rubka.printHelloWorld();
}
