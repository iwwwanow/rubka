const std = @import("std");

const adapter_mod = @import("./infrastructure/adapters/stub.adapter.zig");
const use_case_mod = @import("./application/use-cases/move-window.use-case.zig");
const roeuter_cli_mod = @import("./presentation/cli/router.cli.zig");
const move_window_cli_mod = @import("./presentation/cli/move-window.cli.zig");

const sway_adapter_mod = @import("./infrastructure/adapters/sway.adapter.zig");

// TODO: refactor; mv test imports to root zig
test {
    _ = @import("./infrastructure/adapters/sway.adapter.zig");
}

pub fn main(init: std.process.Init) void {
    var adapter_impl: adapter_mod.StubWindowManagerAdapter = .{};
    const port_impl = adapter_mod.wrap(&adapter_impl);
    const move_window_use_case_impl: use_case_mod.MoveWindowUseCase = .{ .window_manager = port_impl };
    const move_window_cli: move_window_cli_mod.MoveWindowCli = .{ .move_window_use_case = move_window_use_case_impl };
    const router_cli: roeuter_cli_mod.RouterCli = .{ .move_window_cli = move_window_cli };

    var args: std.process.Args.Iterator = init.args.iterate();

    router_cli.process(&args);

    // TODO: env
    // адаптер сам должен вытаскивать переменную по имени. main не должен знать деталей реализации
    // Откуда брать path
    // - Переменная SWAYSOCK. Её выставляет сам sway при старте, и она не системная. Sway кладёт её в окружение своих дочерних процессов, дальше она наследуется по цепочке: sway → терминал → шелл → твоя программа. Из-под sway она есть. Из tty, по ssh или из cron её не будет: там нет sway-родителя. На этот случай у sway есть sway --get-socketpath, но это уже запасной вариант, не для первой версии.
    // - Да, из std.process.Init. Поле environ_map: *Environ.Map (/usr/lib/zig/std/process.zig:44). Метод получения значения найди сам по способу из раздела 3: тип Environ.Map, файл /usr/lib/zig/std/process/Environ.zig, ищи pub fn get. Скорее всего он вернёт optional (?[]const u8): переменной может не быть, и этот случай надо обработать. Вспомни orelse из сессии 08-05, например orelse return error.<свой_тег>.
}
