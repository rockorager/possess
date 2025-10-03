const std = @import("std");
const vt = @import("ghostty");

pub const Terminal = struct {
    allocator: std.mem.Allocator,
    terminal: vt.Terminal,

    pub fn init(allocator: std.mem.Allocator, cols: u16, rows: u16) !Terminal {
        const terminal = try vt.Terminal.init(allocator, .{
            .cols = cols,
            .rows = rows,
        });

        return Terminal{
            .allocator = allocator,
            .terminal = terminal,
        };
    }

    pub fn deinit(self: *Terminal) void {
        self.terminal.deinit(self.allocator);
    }

    pub fn resize(self: *Terminal, cols: u16, rows: u16) !void {
        try self.terminal.resize(self.allocator, cols, rows);
    }
};

test "Terminal init and deinit" {
    var terminal = try Terminal.init(std.testing.allocator, 80, 24);
    defer terminal.deinit();
}

test "Terminal resize" {
    var terminal = try Terminal.init(std.testing.allocator, 80, 24);
    try terminal.resize(40, 12);
    defer terminal.deinit();
}
