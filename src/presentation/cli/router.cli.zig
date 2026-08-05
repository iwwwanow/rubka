// TODO: is it needed to pass from composition root?
const std = @import("std");

const port_mod = @import("../../application/ports/window-manager.port.zig");

const move_window_cli_mod = @import("./move-window.cli.zig");

pub const RouterCli = struct {
    move_window_cli: move_window_cli_mod.MoveWindowCli,

    pub fn process(self: RouterCli) void {
        var args = std.process.args();
        // TODO: why we skip first element?
        _ = args.skip();

        const arg = args.next() orelse {
            // TODO: for what?
            // аргумента нет вообще — решаете сами, что делать
            return;
        };

        const command = std.meta.stringToEnum(port_mod.Direction, arg) orelse {
            // TODO: for what?
            // строка не матчится ни на один таг — неизвестная команда
            return;
        };

        switch (command) {
            .left => self.move_window_cli.left(),
            .right => self.move_window_cli.right(),
        }
    }
};
