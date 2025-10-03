const std = @import("std");
const ghostty = @import("ghostty");

const Stream = ghostty.Stream(*Terminal);

const Size = struct {
    rows: u16,
    cols: u16,
};

pub const TerminalOptions = struct {
    cols: u16,
    rows: u16,
    write_callback_ctx: ?*anyopaque = null,
};

const log = std.log.scoped(.possess);

pub const Terminal = struct {
    allocator: std.mem.Allocator,
    terminal: ghostty.Terminal,
    stream: Stream,
    size: Size,

    /// Opaque pointer to napi callback context for writing to process
    write_callback_ctx: ?*anyopaque = null,

    /// The default cursor state. This is used with CSI q. This is
    /// set to true when we're currently in the default cursor state.
    default_cursor: bool = true,
    default_cursor_style: ghostty.CursorStyle = .block,
    default_cursor_blink: ?bool = null,
    default_cursor_color: ?ghostty.color.RGB = null,

    pub fn init(self: *Terminal, allocator: std.mem.Allocator, options: TerminalOptions) !void {
        const terminal = try ghostty.Terminal.init(allocator, .{
            .cols = options.cols,
            .rows = options.rows,
        });
        const stream = Stream.init(self);
        self.* = .{
            .allocator = allocator,
            .terminal = terminal,
            .stream = stream,
            .size = .{
                .cols = options.cols,
                .rows = options.rows,
            },
            .write_callback_ctx = options.write_callback_ctx,
        };
    }

    pub fn deinit(self: *Terminal) void {
        self.terminal.deinit(self.allocator);
        self.stream.deinit();
    }

    pub fn nextSlice(self: *Terminal, input: []const u8) !void {
        try self.stream.nextSlice(input);
    }

    /// Write bytes to the process. This is called by the terminal when it needs
    /// to send data back to the process (e.g., for device status reports).
    /// The callback_ctx should be a pointer to TerminalContext from main.zig.
    pub fn writeToProcess(self: *Terminal, data: []const u8) void {
        if (self.write_callback_ctx) |ctx| {
            // Call the extern function defined in main.zig
            possess_terminal_write_callback(ctx, data.ptr, data.len);
        }
    }

    /// Queue a render. This is called when the terminal state has changed
    /// and needs to be re-rendered.
    pub fn queueRender(self: *Terminal) void {
        if (self.write_callback_ctx) |ctx| {
            // Call the extern function defined in main.zig
            possess_terminal_queue_render_callback(ctx);
        }
    }

    // These are implemented in main.zig
    extern fn possess_terminal_write_callback(ctx: *anyopaque, data_ptr: [*]const u8, data_len: usize) void;
    extern fn possess_terminal_queue_render_callback(ctx: *anyopaque) void;

    pub fn resize(self: *Terminal, cols: u16, rows: u16) !void {
        try self.terminal.resize(self.allocator, cols, rows);
    }

    pub fn print(self: *Terminal, c: u21) !void {
        try self.terminal.print(c);
    }

    pub fn dcsHook(self: *Terminal, dcs: ghostty.DCS) !void {
        _ = self;
        _ = dcs;
        // TODO: implement
    }

    pub fn dcsPut(self: *Terminal, byte: u8) !void {
        _ = self;
        _ = byte;
        // TODO: implement
    }

    pub fn dcsUnhook(self: *Terminal) !void {
        // TODO: implement
        _ = self;
    }

    pub fn apcStart(self: *Terminal) !void {
        // TODO: implement
        _ = self;
    }

    pub fn apcPut(self: *Terminal, byte: u8) !void {
        // TODO: implement
        _ = self;
        _ = byte;
    }

    pub fn apcEnd(self: *Terminal) !void {
        // TODO: implement
        _ = self;
    }

    pub fn enquiry(self: *Terminal) !void {
        self.writeToProcess(&[_]u8{0x05}); // ENQ response
    }

    pub fn bell(self: *Terminal) !void {
        _ = self;
        // TODO: callback
    }

    pub fn backspace(self: *Terminal) !void {
        self.terminal.backspace();
    }

    pub fn horizontalTab(self: *Terminal, count: u16) !void {
        for (0..count) |_| {
            const x = self.terminal.screen.cursor.x;
            try self.terminal.horizontalTab();
            if (x == self.terminal.screen.cursor.x) break;
        }
    }

    pub fn linefeed(self: *Terminal) !void {
        try self.terminal.linefeed();
    }

    pub fn carriageReturn(self: *Terminal) !void {
        self.terminal.carriageReturn();
    }

    pub fn invokeCharset(
        self: *Terminal,
        active: ghostty.CharsetActiveSlot,
        slot: ghostty.CharsetSlot,
        single: bool,
    ) !void {
        self.terminal.invokeCharset(active, slot, single);
    }

    pub inline fn setCursorLeft(self: *Terminal, amount: u16) !void {
        self.terminal.cursorLeft(amount);
    }

    pub inline fn setCursorRight(self: *Terminal, amount: u16) !void {
        self.terminal.cursorRight(amount);
    }

    pub inline fn setCursorDown(self: *Terminal, amount: u16, carriage: bool) !void {
        self.terminal.cursorDown(amount);
        if (carriage) self.terminal.carriageReturn();
    }

    pub inline fn setCursorUp(self: *Terminal, amount: u16, carriage: bool) !void {
        self.terminal.cursorUp(amount);
        if (carriage) self.terminal.carriageReturn();
    }

    pub inline fn setCursorCol(self: *Terminal, col: u16) !void {
        self.terminal.setCursorPos(self.terminal.screen.cursor.y + 1, col);
    }

    pub inline fn setCursorColRelative(self: *Terminal, offset: u16) !void {
        self.terminal.setCursorPos(
            self.terminal.screen.cursor.y + 1,
            self.terminal.screen.cursor.x + 1 +| offset,
        );
    }

    pub inline fn setCursorRow(self: *Terminal, row: u16) !void {
        self.terminal.setCursorPos(row, self.terminal.screen.cursor.x + 1);
    }

    pub inline fn setCursorRowRelative(self: *Terminal, offset: u16) !void {
        self.terminal.setCursorPos(
            self.terminal.screen.cursor.y + 1 +| offset,
            self.terminal.screen.cursor.x + 1,
        );
    }

    pub inline fn setCursorPos(self: *Terminal, row: u16, col: u16) !void {
        self.terminal.setCursorPos(row, col);
    }

    pub inline fn eraseDisplay(self: *Terminal, mode: ghostty.EraseDisplay, protected: bool) !void {
        if (mode == .complete) {
            // Whenever we erase the full display, scroll to bottom.
            try self.terminal.scrollViewport(.{ .bottom = {} });
            self.queueRender();
        }

        self.terminal.eraseDisplay(mode, protected);
    }

    pub inline fn eraseLine(self: *Terminal, mode: ghostty.EraseLine, protected: bool) !void {
        self.terminal.eraseLine(mode, protected);
    }

    pub inline fn deleteChars(self: *Terminal, count: usize) !void {
        self.terminal.deleteChars(count);
    }

    pub inline fn eraseChars(self: *Terminal, count: usize) !void {
        self.terminal.eraseChars(count);
    }

    pub inline fn insertLines(self: *Terminal, count: usize) !void {
        self.terminal.insertLines(count);
    }

    pub inline fn insertBlanks(self: *Terminal, count: usize) !void {
        self.terminal.insertBlanks(count);
    }

    pub inline fn deleteLines(self: *Terminal, count: usize) !void {
        self.terminal.deleteLines(count);
    }

    pub inline fn reverseIndex(self: *Terminal) !void {
        self.terminal.reverseIndex();
    }

    pub inline fn index(self: *Terminal) !void {
        try self.terminal.index();
    }

    pub inline fn nextLine(self: *Terminal) !void {
        try self.terminal.index();
        self.terminal.carriageReturn();
    }

    pub inline fn setTopAndBottomMargin(self: *Terminal, top: u16, bot: u16) !void {
        self.terminal.setTopAndBottomMargin(top, bot);
    }

    pub inline fn setLeftAndRightMarginAmbiguous(self: *Terminal) !void {
        if (self.terminal.modes.get(.enable_left_and_right_margin)) {
            try self.setLeftAndRightMargin(0, 0);
        } else {
            self.terminal.saveCursor();
        }
    }

    pub inline fn setLeftAndRightMargin(self: *Terminal, left: u16, right: u16) !void {
        self.terminal.setLeftAndRightMargin(left, right);
    }

    pub inline fn scrollDown(self: *Terminal, count: usize) !void {
        self.terminal.scrollDown(count);
    }

    pub inline fn scrollUp(self: *Terminal, count: usize) !void {
        self.terminal.scrollUp(count);
    }

    pub inline fn tabClear(self: *Terminal, cmd: ghostty.TabClear) !void {
        self.terminal.tabClear(cmd);
    }

    pub inline fn tabSet(self: *Terminal) !void {
        self.terminal.tabSet();
    }

    pub inline fn tabReset(self: *Terminal) !void {
        self.terminal.tabReset();
    }

    pub inline fn horizontalTabBack(self: *Terminal, count: u16) !void {
        for (0..count) |_| {
            const x = self.terminal.screen.cursor.x;
            try self.terminal.horizontalTabBack();
            if (x == self.terminal.screen.cursor.x) break;
        }
    }

    pub inline fn printRepeat(self: *Terminal, count: usize) !void {
        try self.terminal.printRepeat(count);
    }

    pub fn deviceAttributes(
        self: *Terminal,
        req: ghostty.DeviceAttributeReq,
        params: []const u16,
    ) !void {
        _ = params;

        // For the below, we quack as a VT220. We don't quack as
        // a 420 because we don't support DCS sequences.
        switch (req) {
            .primary => {
                // 62 = Level 2 conformance
                // 22 = Color text
                self.writeToProcess("\x1B[?62;22c");
            },

            .secondary => {
                self.writeToProcess("\x1B[>1;10;0c");
            },

            else => log.warn("unimplemented device attributes req: {}", .{req}),
        }
    }

    pub fn deviceStatusReport(
        self: *Terminal,
        req: ghostty.device_status.Request,
    ) !void {
        switch (req) {
            .operating_status => self.writeToProcess("\x1B[0n"),

            .cursor_position => {
                const pos: struct {
                    x: usize,
                    y: usize,
                } = if (self.terminal.modes.get(.origin)) .{
                    .x = self.terminal.screen.cursor.x -| self.terminal.scrolling_region.left,
                    .y = self.terminal.screen.cursor.y -| self.terminal.scrolling_region.top,
                } else .{
                    .x = self.terminal.screen.cursor.x,
                    .y = self.terminal.screen.cursor.y,
                };

                // Response always is at least 4 chars, so this leaves the
                // remainder for the row/column as base-10 numbers. This
                // will support a very large terminal.
                var buf: [64]u8 = undefined;
                const resp = try std.fmt.bufPrint(&buf, "\x1B[{d};{d}R", .{
                    pos.y + 1,
                    pos.x + 1,
                });

                self.writeToProcess(resp);
            },

            .color_scheme => {
                // TODO: implement color scheme reporting
            },
        }
    }

    pub inline fn setProtectedMode(self: *Terminal, mode: ghostty.ProtectedMode) !void {
        self.terminal.setProtectedMode(mode);
    }

    pub fn setMode(self: *Terminal, mode: ghostty.Mode, enabled: bool) !void {
        // Note: this function doesn't need to grab the render state or
        // terminal locks because it is only called from process() which
        // grabs the lock.

        // If we are setting cursor blinking, we ignore it if we have
        // a default cursor blink setting set. This is a really weird
        // behavior so this comment will go deep into trying to explain it.
        //
        // There are two ways to set cursor blinks: DECSCUSR (CSI _ q)
        // and DEC mode 12. DECSCUSR is the modern approach and has a
        // way to revert to the "default" (as defined by the terminal)
        // cursor style and blink by doing "CSI 0 q". DEC mode 12 controls
        // blinking and is either on or off and has no way to set a
        // default. DEC mode 12 is also the more antiquated approach.
        //
        // The problem is that if the user specifies a desired default
        // cursor blink with `cursor-style-blink`, the moment a running
        // program uses DEC mode 12, the cursor blink can never be reset
        // to the default without an explicit DECSCUSR. But if a program
        // is using mode 12, it is by definition not using DECSCUSR.
        // This makes for somewhat annoying interactions where a poorly
        // (or legacy) behaved program will stop blinking, and it simply
        // never restarts.
        //
        // To get around this, we have a special case where if the user
        // specifies some explicit default cursor blink desire, we ignore
        // DEC mode 12. We allow DECSCUSR to still set the cursor blink
        // because programs using DECSCUSR usually are well behaved and
        // reset the cursor blink to the default when they exit.
        //
        // To be extra safe, users can also add a manual `CSI 0 q` to
        // their shell config when they render prompts to ensure the
        // cursor is exactly as they request.
        if (mode == .cursor_blinking and
            self.default_cursor_blink != null)
        {
            return;
        }

        // We first always set the raw mode on our mode state.
        self.terminal.modes.set(mode, enabled);

        // And then some modes require additional processing.
        switch (mode) {
            // Just noting here that autorepeat has no effect on
            // the terminal. xterm ignores this mode and so do we.
            // We know about just so that we don't log that it is
            // an unknown mode.
            .autorepeat => {},

            // Schedule a render since we changed colors
            .reverse_colors => {
                self.terminal.flags.dirty.reverse_colors = true;
                self.queueRender();
            },

            // Origin resets cursor pos. This is called whether or not
            // we're enabling or disabling origin mode and whether or
            // not the value changed.
            .origin => self.terminal.setCursorPos(1, 1),

            .enable_left_and_right_margin => if (!enabled) {
                // When we disable left/right margin mode we need to
                // reset the left/right margins.
                self.terminal.scrolling_region.left = 0;
                self.terminal.scrolling_region.right = self.terminal.cols - 1;
            },

            .alt_screen_legacy => {
                self.terminal.switchScreenMode(.@"47", enabled);
                self.queueRender();
            },

            .alt_screen => {
                self.terminal.switchScreenMode(.@"1047", enabled);
                self.queueRender();
            },

            .alt_screen_save_cursor_clear_enter => {
                self.terminal.switchScreenMode(.@"1049", enabled);
                self.queueRender();
            },

            // Mode 1048 is xterm's conditional save cursor depending
            // on if alt screen is enabled or not (at the terminal emulator
            // level). Alt screen is always enabled for us so this just
            // does a save/restore cursor.
            .save_cursor => {
                if (enabled) {
                    self.terminal.saveCursor();
                } else {
                    try self.terminal.restoreCursor();
                }
            },

            // Force resize back to the window size
            .enable_mode_3 => {
                self.terminal.resize(
                    self.allocator,
                    self.size.cols,
                    self.size.rows,
                ) catch |err| {
                    log.err("error updating terminal size: {}", .{err});
                };
            },

            .@"132_column" => try self.terminal.deccolm(
                self.allocator,
                if (enabled) .@"132_cols" else .@"80_cols",
            ),

            // We need to start a timer to prevent the emulator being hung
            // forever.
            .synchronized_output => {
                // TODO: send sync message
                // if (enabled) self.messageWriter(.{ .start_synchronized_output = {} });
                self.queueRender();
            },

            .linefeed => {
                // TODO: send linefeed mode
                // self.messageWriter(.{ .linefeed_mode = enabled });
            },

            .in_band_size_reports => {
                // TODO:
                // if (enabled) self.messageWriter(.{
                //     .size_report = .mode_2048,
                // });
            },

            .focus_event => {
                // TODO:
                // if (enabled) self.messageWriter(.{
                //     .focused = self.terminal.flags.focused,
                // });
            },

            .mouse_event_x10 => {
                if (enabled) {
                    self.terminal.flags.mouse_event = .x10;
                    // try self.setMouseShape(.default);
                } else {
                    self.terminal.flags.mouse_event = .none;
                    // try self.setMouseShape(.text);
                }
            },
            .mouse_event_normal => {
                if (enabled) {
                    self.terminal.flags.mouse_event = .normal;
                    // try self.setMouseShape(.default);
                } else {
                    self.terminal.flags.mouse_event = .none;
                    // try self.setMouseShape(.text);
                }
            },
            .mouse_event_button => {
                if (enabled) {
                    self.terminal.flags.mouse_event = .button;
                    // try self.setMouseShape(.default);
                } else {
                    self.terminal.flags.mouse_event = .none;
                    // try self.setMouseShape(.text);
                }
            },
            .mouse_event_any => {
                if (enabled) {
                    self.terminal.flags.mouse_event = .any;
                    // try self.setMouseShape(.default);
                } else {
                    self.terminal.flags.mouse_event = .none;
                    // try self.setMouseShape(.text);
                }
            },

            .mouse_format_utf8 => self.terminal.flags.mouse_format = if (enabled) .utf8 else .x10,
            .mouse_format_sgr => self.terminal.flags.mouse_format = if (enabled) .sgr else .x10,
            .mouse_format_urxvt => self.terminal.flags.mouse_format = if (enabled) .urxvt else .x10,
            .mouse_format_sgr_pixels => self.terminal.flags.mouse_format = if (enabled) .sgr_pixels else .x10,

            else => {},
        }
    }

    pub fn setModifyKeyFormat(self: *Terminal, format: ghostty.ModifyKeyFormat) !void {
        self.terminal.flags.modify_other_keys_2 = false;
        switch (format) {
            .other_keys => |v| switch (v) {
                .numeric => self.terminal.flags.modify_other_keys_2 = true,
                else => {},
            },
            else => {},
        }
    }

    pub inline fn setAttribute(self: *Terminal, attr: ghostty.Attribute) !void {
        switch (attr) {
            .unknown => |unk| log.warn("unimplemented or unknown SGR attribute: {any}", .{unk}),

            else => self.terminal.setAttribute(attr) catch |err|
                log.warn("error setting attribute {}: {}", .{ attr, err }),
        }
    }

    pub fn requestMode(self: *Terminal, mode_raw: u16, ansi: bool) !void {
        // Get the mode value and respond.
        const code: u8 = code: {
            const mode = ghostty.modes.modeFromInt(mode_raw, ansi) orelse break :code 0;
            if (self.terminal.modes.get(mode)) break :code 1;
            break :code 2;
        };

        var buf: [32]u8 = undefined;
        const resp = try std.fmt.bufPrint(
            &buf,
            "\x1B[{s}{};{}$y",
            .{
                if (ansi) "" else "?",
                mode_raw,
                code,
            },
        );
        self.writeToProcess(resp);
    }

    /// Get the dimensions of the active screen
    pub fn getScreenDimensions(self: *Terminal) Size {
        return self.size;
    }

    /// Check if any rows in the active screen have dirty bits set
    pub fn hasAnyDirtyRows(self: *Terminal) bool {
        const pt = ghostty.point.Point{ .screen = .{ .x = 0, .y = 0 } };
        const cell_ref = self.terminal.screen.pages.getCell(pt) orelse return false;
        return cell_ref.node.data.isDirty();
    }

    /// Get the state of a terminal mode by its numeric value
    /// For DEC private modes (like 2026, 2004), use the mode number directly
    pub fn getMode(self: *Terminal, mode_num: u16) bool {
        // Try DEC private mode first (most common terminal modes use this)
        const mode = ghostty.modes.modeFromInt(mode_num, false) orelse {
            // Fall back to ANSI mode
            const ansi_mode = ghostty.modes.modeFromInt(mode_num, true) orelse return false;
            return self.terminal.modes.get(ansi_mode);
        };
        return self.terminal.modes.get(mode);
    }

    /// Check if synchronized output mode (2026) is enabled
    pub fn isSyncModeEnabled(self: *Terminal) bool {
        return self.terminal.modes.get(.synchronized_output);
    }

    /// Clear all terminal and screen dirty flags after rendering
    /// Note: This does NOT clear row-level dirty bits - use clearRowDirty for that
    pub fn clearDirty(self: *Terminal) void {
        self.terminal.flags.dirty = .{};
        self.terminal.screen.dirty = .{};
    }

    /// Clear the dirty bit for a specific row
    pub fn clearRowDirty(self: *Terminal, row: u16) void {
        const pt = ghostty.point.Point{ .screen = .{ .x = 0, .y = row } };
        const cell_ref = self.terminal.screen.pages.getCell(pt) orelse return;
        var dirty = cell_ref.node.data.dirtyBitSet();
        const pin = self.terminal.screen.pages.pin(pt) orelse return;
        if (pin.y < dirty.bit_length) {
            dirty.unset(pin.y);
        }
    }

    /// Check if a specific row is dirty
    pub fn isRowDirty(self: *Terminal, row: u16) bool {
        const pt = ghostty.point.Point{ .screen = .{ .x = 0, .y = row } };
        const cell_ref = self.terminal.screen.pages.getCell(pt) orelse return false;
        const pin = self.terminal.screen.pages.pin(pt) orelse return false;
        return cell_ref.node.data.isRowDirty(pin.y);
    }

    /// Cell reference from page list
    const CellRef = struct {
        page: *const ghostty.Page,
        cell: *const ghostty.Cell,
    };

    /// Get a cell reference at a specific position in the active screen
    /// Returns null if the position is out of bounds
    pub fn getCellRef(self: *Terminal, x: u16, y: u16) ?CellRef {
        if (x >= self.size.cols or y >= self.size.rows) return null;

        // Use PageList.getCell which takes a Point
        const pt = ghostty.point.Point{
            .screen = .{ .x = x, .y = y },
        };
        const cell_ref = self.terminal.screen.pages.getCell(pt) orelse return null;
        return .{
            .page = &cell_ref.node.data,
            .cell = cell_ref.cell,
        };
    }

    /// RGB color structure
    pub const RGB = struct {
        r: u8,
        g: u8,
        b: u8,
    };

    /// Maximum UTF-8 encoded grapheme size (4 bytes per codepoint * 16 codepoints)
    const MAX_GRAPHEME_BYTES = 64;

    /// Cell data structure with actual displayable information
    pub const CellData = struct {
        // Text content - UTF-8 encoded grapheme text
        text: [MAX_GRAPHEME_BYTES]u8,
        text_len: u8,

        // Layout
        wide: u2, // 0 = narrow, 1 = wide, 2 = spacer_tail, 3 = spacer_head

        // Style - colors
        fg_color_type: u8, // 0 = none/default, 1 = palette, 2 = rgb
        fg_palette_idx: u8,
        fg_rgb: RGB,

        bg_color_type: u8, // 0 = none/default, 1 = palette, 2 = rgb
        bg_palette_idx: u8,
        bg_rgb: RGB,

        // Style - flags
        bold: bool,
        italic: bool,
        faint: bool,
        inverse: bool,
        invisible: bool,
        strikethrough: bool,
        underline: u4, // From sgr.Attribute.Underline enum
    };

    /// Extract complete cell data including grapheme and style
    pub fn extractCellData(cell_ref: CellRef) CellData {
        const cell = cell_ref.cell;
        const page = cell_ref.page;

        // Spacer cells don't have their own style, and style_id 0 is default
        const style_ptr = if (cell.wide == .spacer_tail or cell.wide == .spacer_head or cell.style_id == 0)
            null
        else
            page.styles.get(page.memory, cell.style_id);

        const style = if (style_ptr) |s| s.* else ghostty.Style{};

        // Extract grapheme data if it's a multi-codepoint grapheme
        const grapheme = if (cell.content_tag == .codepoint_grapheme)
            page.lookupGrapheme(cell)
        else
            null;

        var data = CellData{
            .text = undefined,
            .text_len = 0,
            .wide = @intFromEnum(cell.wide),

            // Colors - defaults
            .fg_color_type = 0,
            .fg_palette_idx = 0,
            .fg_rgb = .{ .r = 0, .g = 0, .b = 0 },
            .bg_color_type = 0,
            .bg_palette_idx = 0,
            .bg_rgb = .{ .r = 0, .g = 0, .b = 0 },

            // Style flags
            .bold = style.flags.bold,
            .italic = style.flags.italic,
            .faint = style.flags.faint,
            .inverse = style.flags.inverse,
            .invisible = style.flags.invisible,
            .strikethrough = style.flags.strikethrough,
            .underline = @intFromEnum(style.flags.underline),
        };

        // Encode grapheme to UTF-8
        const primary_cp = switch (cell.content_tag) {
            .codepoint, .codepoint_grapheme => cell.content.codepoint,
            .bg_color_palette, .bg_color_rgb => 0,
        };

        var write_pos: usize = 0;

        // Encode primary codepoint
        if (primary_cp != 0) {
            const len = std.unicode.utf8Encode(primary_cp, data.text[write_pos..]) catch 0;
            write_pos += len;
        }

        // Encode additional grapheme codepoints if present
        if (grapheme) |g| {
            for (g) |cp| {
                if (write_pos + 4 > MAX_GRAPHEME_BYTES) break;
                const len = std.unicode.utf8Encode(cp, data.text[write_pos..]) catch 0;
                write_pos += len;
            }
        }

        data.text_len = @intCast(write_pos);

        // Extract foreground color
        switch (style.fg_color) {
            .none => {},
            .palette => |idx| {
                data.fg_color_type = 1;
                data.fg_palette_idx = idx;
            },
            .rgb => |rgb| {
                data.fg_color_type = 2;
                data.fg_rgb = .{ .r = rgb.r, .g = rgb.g, .b = rgb.b };
            },
        }

        // Extract background color (check cell content tag first)
        switch (cell.content_tag) {
            .bg_color_palette => {
                data.bg_color_type = 1;
                data.bg_palette_idx = cell.content.color_palette;
            },
            .bg_color_rgb => {
                const rgb = cell.content.color_rgb;
                data.bg_color_type = 2;
                data.bg_rgb = .{ .r = rgb.r, .g = rgb.g, .b = rgb.b };
            },
            else => {
                switch (style.bg_color) {
                    .none => {},
                    .palette => |idx| {
                        data.bg_color_type = 1;
                        data.bg_palette_idx = idx;
                    },
                    .rgb => |rgb| {
                        data.bg_color_type = 2;
                        data.bg_rgb = .{ .r = rgb.r, .g = rgb.g, .b = rgb.b };
                    },
                }
            },
        }

        return data;
    }
};

test "Terminal init and deinit" {
    var terminal: Terminal = undefined;
    try terminal.init(std.testing.allocator, .{ .cols = 80, .rows = 24 });
    defer terminal.deinit();
}

test "Terminal resize" {
    var terminal: Terminal = undefined;
    try terminal.init(std.testing.allocator, .{ .cols = 80, .rows = 24 });
    try terminal.resize(40, 12);
    defer terminal.deinit();
}

test "Terminal nextSlice" {
    var terminal: Terminal = undefined;
    try terminal.init(std.testing.allocator, .{ .cols = 80, .rows = 24 });
    try terminal.nextSlice("hello");
    defer terminal.deinit();
}
