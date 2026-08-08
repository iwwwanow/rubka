const std = @import("std");

const adapter_mod = @import("./infrastructure/adapters/stub.adapter.zig");
const use_case_mod = @import("./application/use-cases/move-window.use-case.zig");
const roeuter_cli_mod = @import("./presentation/cli/router.cli.zig");
const move_window_cli_mod = @import("./presentation/cli/move-window.cli.zig");

const sway_adapter_mod = @import("./infrastructure/adapters/sway.adapter.zig");

pub fn main(init: std.process.Init.Minimal) void {
    var adapter_impl: adapter_mod.StubWindowManagerAdapter = .{};
    const port_impl = adapter_mod.wrap(&adapter_impl);
    const move_window_use_case_impl: use_case_mod.MoveWindowUseCase = .{ .window_manager = port_impl };
    const move_window_cli: move_window_cli_mod.MoveWindowCli = .{ .move_window_use_case = move_window_use_case_impl };
    const router_cli: roeuter_cli_mod.RouterCli = .{ .move_window_cli = move_window_cli };

    var args: std.process.Args.Iterator = init.args.iterate();

    router_cli.process(&args);
}
