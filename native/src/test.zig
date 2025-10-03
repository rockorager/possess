const std = @import("std");

// Stub implementation for terminal tests
export fn possess_terminal_write_callback(ctx: *anyopaque, data_ptr: [*]const u8, data_len: usize) void {
    _ = ctx;
    _ = data_ptr;
    _ = data_len;
}

export fn possess_terminal_queue_render_callback(ctx: *anyopaque) void {
    _ = ctx;
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("terminal.zig");
}
