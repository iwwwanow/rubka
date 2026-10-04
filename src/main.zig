const std = @import("std");

const use_case_mod = @import("./application/use-cases/move-window.use-case.zig");
const roeuter_cli_mod = @import("./presentation/cli/router.cli.zig");
const move_window_cli_mod = @import("./presentation/cli/move-window.cli.zig");

const sway_adapter_mod = @import("./infrastructure/adapters/sway.adapter.zig");

// TODO: refactor; mv test imports to root zig
test {
    _ = @import("./infrastructure/adapters/sway.adapter.zig");
}

pub fn main(init: std.process.Init) void {
    var adapter_impl: sway_adapter_mod.SwayWindowManagerAdapter = .{};
    const port_impl = sway_adapter_mod.wrap(&adapter_impl, init.io, init.environ_map) catch |err| {
        std.log.err("Error on sway-adapter, wrap: {}", .{err});
        return;
    };
    const move_window_use_case_impl: use_case_mod.MoveWindowUseCase = .{ .window_manager = port_impl };
    const move_window_cli: move_window_cli_mod.MoveWindowCli = .{ .move_window_use_case = move_window_use_case_impl };
    const router_cli: roeuter_cli_mod.RouterCli = .{ .move_window_cli = move_window_cli };

    var args: std.process.Args.Iterator = init.minimal.args.iterate();

    router_cli.process(&args);
}
