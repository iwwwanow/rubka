pub const i3_ipc_magic = "i3-ipc";

pub const MessageType = enum(u32) {
    run_command = 0,
    get_workspaces = 1,
    subscribe = 2,
    get_outputs = 3,
    get_tree = 4,
    get_marks = 5,
    get_bar_config = 6,
    get_version = 7,
    get_binding_modes = 8,
    get_config = 9,
    send_tick = 10,
    sync = 11,
    get_binding_state = 12,
    get_inputs = 100,
    get_seats = 101,
    _,
};

pub const EventType = enum(u32) {
    workspace = 0,
    output = 1,
    mode = 2,
    window = 3,
    barconfig_update = 4,
    binding = 5,
    shutdown = 6,
    tick = 7,
    bar_state_update = 20,
    input = 21,
    _,
};
