const std = @import("std");
const terminal_mod = @import("terminal.zig");
const Terminal = terminal_mod.Terminal;
const TerminalOptions = terminal_mod.TerminalOptions;

const c = @cImport({
    @cInclude("node_api.h");
});

/// Context for each terminal instance
const TerminalContext = struct {
    terminal: Terminal,
    env: c.napi_env,
    callback_ref: c.napi_ref,
};

/// Callback function called from terminal.zig when it needs to write to the process
export fn possess_terminal_write_callback(ctx: *anyopaque, data_ptr: [*]const u8, data_len: usize) void {
    const self: *TerminalContext = @ptrCast(@alignCast(ctx));

    // Create a copy of the data in a JS buffer
    var buffer: c.napi_value = undefined;
    const status = c.napi_create_buffer_copy(
        self.env,
        data_len,
        data_ptr,
        null,
        &buffer,
    );
    if (status != c.napi_ok) return;

    // Get the callback function from the ref
    var callback: c.napi_value = undefined;
    if (c.napi_get_reference_value(self.env, self.callback_ref, &callback) != c.napi_ok) return;

    // Call the callback with the buffer
    var global: c.napi_value = undefined;
    _ = c.napi_get_global(self.env, &global);

    var result: c.napi_value = undefined;
    _ = c.napi_call_function(self.env, global, callback, 1, &buffer, &result);
}

export fn napi_register_module_v1(env: c.napi_env, exports: c.napi_value) c.napi_value {
    // Register createTerminal function
    var create_func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, createTerminal, null, &create_func);
    _ = c.napi_set_named_property(env, exports, "createTerminal", create_func);

    return exports;
}

fn createTerminal(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    // Get arguments: options object
    var argc: usize = 1;
    var args: [1]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &args, null, null) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to parse arguments");
        return null;
    }

    if (argc < 1) {
        _ = c.napi_throw_error(env, null, "Expected 1 argument: options object");
        return null;
    }

    const options = args[0];

    // Extract cols from options.cols
    var cols_val: c.napi_value = undefined;
    if (c.napi_get_named_property(env, options, "cols", &cols_val) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "options.cols is required");
        return null;
    }
    var cols_u32: u32 = 0;
    if (c.napi_get_value_uint32(env, cols_val, &cols_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "options.cols must be a number");
        return null;
    }

    // Extract rows from options.rows
    var rows_val: c.napi_value = undefined;
    if (c.napi_get_named_property(env, options, "rows", &rows_val) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "options.rows is required");
        return null;
    }
    var rows_u32: u32 = 0;
    if (c.napi_get_value_uint32(env, rows_val, &rows_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "options.rows must be a number");
        return null;
    }

    // Extract callback from options.onWrite
    var callback_val: c.napi_value = undefined;
    if (c.napi_get_named_property(env, options, "onWrite", &callback_val) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "options.onWrite is required");
        return null;
    }

    // Create a reference to the callback
    var callback_ref: c.napi_ref = undefined;
    if (c.napi_create_reference(env, callback_val, 1, &callback_ref) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to create callback reference");
        return null;
    }

    // Allocate terminal context
    const allocator = std.heap.c_allocator;
    const ctx = allocator.create(TerminalContext) catch {
        _ = c.napi_delete_reference(env, callback_ref);
        _ = c.napi_throw_error(env, null, "Failed to allocate terminal context");
        return null;
    };

    // Set up the context
    ctx.env = env;
    ctx.callback_ref = callback_ref;

    // Initialize terminal with options
    ctx.terminal.init(allocator, .{
        .cols = @intCast(cols_u32),
        .rows = @intCast(rows_u32),
        .write_callback_ctx = ctx,
    }) catch {
        allocator.destroy(ctx);
        _ = c.napi_delete_reference(env, callback_ref);
        _ = c.napi_throw_error(env, null, "Failed to initialize terminal");
        return null;
    };

    // Create the JS object with write and dispose methods
    var terminal_obj: c.napi_value = undefined;
    _ = c.napi_create_object(env, &terminal_obj);

    // Store the context pointer as an external value
    var external: c.napi_value = undefined;
    _ = c.napi_create_external(env, ctx, null, null, &external);
    _ = c.napi_set_named_property(env, terminal_obj, "_ctx", external);

    // Add write method
    var write_func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, terminalWrite, null, &write_func);
    _ = c.napi_set_named_property(env, terminal_obj, "write", write_func);

    // Add dispose method
    var dispose_func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, terminalDispose, null, &dispose_func);
    _ = c.napi_set_named_property(env, terminal_obj, "dispose", dispose_func);

    // Add getScreenDimensions method
    var get_dims_func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, terminalGetScreenDimensions, null, &get_dims_func);
    _ = c.napi_set_named_property(env, terminal_obj, "getScreenDimensions", get_dims_func);

    // Add getCellData method
    var get_cell_func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, terminalGetCellData, null, &get_cell_func);
    _ = c.napi_set_named_property(env, terminal_obj, "getCellData", get_cell_func);

    // Add getRow method
    var get_row_func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, terminalGetRow, null, &get_row_func);
    _ = c.napi_set_named_property(env, terminal_obj, "getRow", get_row_func);

    // Add getRegion method
    var get_region_func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, terminalGetRegion, null, &get_region_func);
    _ = c.napi_set_named_property(env, terminal_obj, "getRegion", get_region_func);

    // Add getAllCells method
    var get_all_func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, terminalGetAllCells, null, &get_all_func);
    _ = c.napi_set_named_property(env, terminal_obj, "getAllCells", get_all_func);

    return terminal_obj;
}

fn terminalWrite(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    // Get 'this' and arguments
    var argc: usize = 1;
    var args: [1]c.napi_value = undefined;
    var this: c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &args, &this, null) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to parse arguments");
        return null;
    }

    if (argc < 1) {
        _ = c.napi_throw_error(env, null, "Expected 1 argument: data");
        return null;
    }

    // Get the context
    var ctx_val: c.napi_value = undefined;
    if (c.napi_get_named_property(env, this, "_ctx", &ctx_val) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to get terminal context");
        return null;
    }

    var ctx: ?*TerminalContext = null;
    if (c.napi_get_value_external(env, ctx_val, @ptrCast(&ctx)) != c.napi_ok or ctx == null) {
        _ = c.napi_throw_error(env, null, "Invalid terminal context");
        return null;
    }

    // Get buffer data
    var is_buffer: bool = false;
    if (c.napi_is_buffer(env, args[0], &is_buffer) != c.napi_ok or !is_buffer) {
        _ = c.napi_throw_error(env, null, "Argument must be a Buffer or Uint8Array");
        return null;
    }

    var data: ?*anyopaque = null;
    var length: usize = 0;
    if (c.napi_get_buffer_info(env, args[0], &data, &length) != c.napi_ok or data == null) {
        _ = c.napi_throw_error(env, null, "Failed to get buffer data");
        return null;
    }

    // Call nextSlice on the terminal
    const bytes: [*]const u8 = @ptrCast(data);
    ctx.?.terminal.nextSlice(bytes[0..length]) catch {
        _ = c.napi_throw_error(env, null, "Failed to process terminal input");
        return null;
    };

    return null;
}

fn terminalDispose(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    // Get 'this'
    var this: c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, null, null, &this, null) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to get this");
        return null;
    }

    // Get the context
    var ctx_val: c.napi_value = undefined;
    if (c.napi_get_named_property(env, this, "_ctx", &ctx_val) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to get terminal context");
        return null;
    }

    var ctx: ?*TerminalContext = null;
    if (c.napi_get_value_external(env, ctx_val, @ptrCast(&ctx)) != c.napi_ok or ctx == null) {
        _ = c.napi_throw_error(env, null, "Invalid terminal context");
        return null;
    }

    // Clean up
    if (ctx) |c_ptr| {
        c_ptr.terminal.deinit();
        _ = c.napi_delete_reference(env, c_ptr.callback_ref);
        std.heap.c_allocator.destroy(c_ptr);
    }

    return null;
}

fn terminalGetScreenDimensions(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    // Get 'this'
    var this: c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, null, null, &this, null) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to get this");
        return null;
    }

    // Get the context
    var ctx: ?*TerminalContext = null;
    if (!getTerminalContext(env, this, &ctx)) return null;

    const dims = ctx.?.terminal.getScreenDimensions();

    // Create result object { rows, cols }
    var result: c.napi_value = undefined;
    _ = c.napi_create_object(env, &result);

    var rows: c.napi_value = undefined;
    _ = c.napi_create_uint32(env, dims.rows, &rows);
    _ = c.napi_set_named_property(env, result, "rows", rows);

    var cols: c.napi_value = undefined;
    _ = c.napi_create_uint32(env, dims.cols, &cols);
    _ = c.napi_set_named_property(env, result, "cols", cols);

    return result;
}

fn terminalGetCellData(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    // Get 'this' and arguments
    var argc: usize = 2;
    var args: [2]c.napi_value = undefined;
    var this: c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &args, &this, null) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to parse arguments");
        return null;
    }

    if (argc < 2) {
        _ = c.napi_throw_error(env, null, "Expected 2 arguments: row, col");
        return null;
    }

    // Get the context
    var ctx: ?*TerminalContext = null;
    if (!getTerminalContext(env, this, &ctx)) return null;

    // Get row and col arguments
    var row_u32: u32 = 0;
    if (c.napi_get_value_uint32(env, args[0], &row_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "row must be a number");
        return null;
    }

    var col_u32: u32 = 0;
    if (c.napi_get_value_uint32(env, args[1], &col_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "col must be a number");
        return null;
    }

    // Get the cell reference
    const cell_ref = ctx.?.terminal.getCellRef(@intCast(col_u32), @intCast(row_u32));
    if (cell_ref == null) {
        _ = c.napi_throw_error(env, null, "Cell position out of bounds");
        return null;
    }

    const cell_data = Terminal.extractCellData(cell_ref.?);

    return createCellDataObject(env, cell_data);
}

/// Helper function to get terminal context from 'this'
fn getTerminalContext(env: c.napi_env, this: c.napi_value, ctx: *?*TerminalContext) bool {
    var ctx_val: c.napi_value = undefined;
    if (c.napi_get_named_property(env, this, "_ctx", &ctx_val) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to get terminal context");
        return false;
    }

    if (c.napi_get_value_external(env, ctx_val, @ptrCast(ctx)) != c.napi_ok or ctx.* == null) {
        _ = c.napi_throw_error(env, null, "Invalid terminal context");
        return false;
    }

    return true;
}

/// Helper to create cell data object from CellData struct
fn createCellDataObject(env: c.napi_env, cell_data: Terminal.CellData) c.napi_value {
    var result: c.napi_value = undefined;
    _ = c.napi_create_object(env, &result);

    // Text content - UTF-8 encoded grapheme
    var text: c.napi_value = undefined;
    _ = c.napi_create_string_utf8(env, @ptrCast(cell_data.text[0..cell_data.text_len]), cell_data.text_len, &text);
    _ = c.napi_set_named_property(env, result, "text", text);

    // Layout
    var wide: c.napi_value = undefined;
    _ = c.napi_create_uint32(env, cell_data.wide, &wide);
    _ = c.napi_set_named_property(env, result, "wide", wide);

    // Foreground color
    var fg_obj: c.napi_value = undefined;
    _ = c.napi_create_object(env, &fg_obj);

    var fg_type: c.napi_value = undefined;
    _ = c.napi_create_uint32(env, cell_data.fg_color_type, &fg_type);
    _ = c.napi_set_named_property(env, fg_obj, "type", fg_type);

    if (cell_data.fg_color_type == 1) {
        var fg_idx: c.napi_value = undefined;
        _ = c.napi_create_uint32(env, cell_data.fg_palette_idx, &fg_idx);
        _ = c.napi_set_named_property(env, fg_obj, "paletteIdx", fg_idx);
    } else if (cell_data.fg_color_type == 2) {
        var fg_r: c.napi_value = undefined;
        _ = c.napi_create_uint32(env, cell_data.fg_rgb.r, &fg_r);
        _ = c.napi_set_named_property(env, fg_obj, "r", fg_r);

        var fg_g: c.napi_value = undefined;
        _ = c.napi_create_uint32(env, cell_data.fg_rgb.g, &fg_g);
        _ = c.napi_set_named_property(env, fg_obj, "g", fg_g);

        var fg_b: c.napi_value = undefined;
        _ = c.napi_create_uint32(env, cell_data.fg_rgb.b, &fg_b);
        _ = c.napi_set_named_property(env, fg_obj, "b", fg_b);
    }
    _ = c.napi_set_named_property(env, result, "fg", fg_obj);

    // Background color
    var bg_obj: c.napi_value = undefined;
    _ = c.napi_create_object(env, &bg_obj);

    var bg_type: c.napi_value = undefined;
    _ = c.napi_create_uint32(env, cell_data.bg_color_type, &bg_type);
    _ = c.napi_set_named_property(env, bg_obj, "type", bg_type);

    if (cell_data.bg_color_type == 1) {
        var bg_idx: c.napi_value = undefined;
        _ = c.napi_create_uint32(env, cell_data.bg_palette_idx, &bg_idx);
        _ = c.napi_set_named_property(env, bg_obj, "paletteIdx", bg_idx);
    } else if (cell_data.bg_color_type == 2) {
        var bg_r: c.napi_value = undefined;
        _ = c.napi_create_uint32(env, cell_data.bg_rgb.r, &bg_r);
        _ = c.napi_set_named_property(env, bg_obj, "r", bg_r);

        var bg_g: c.napi_value = undefined;
        _ = c.napi_create_uint32(env, cell_data.bg_rgb.g, &bg_g);
        _ = c.napi_set_named_property(env, bg_obj, "g", bg_g);

        var bg_b: c.napi_value = undefined;
        _ = c.napi_create_uint32(env, cell_data.bg_rgb.b, &bg_b);
        _ = c.napi_set_named_property(env, bg_obj, "b", bg_b);
    }
    _ = c.napi_set_named_property(env, result, "bg", bg_obj);

    // Style flags
    var bold: c.napi_value = undefined;
    _ = c.napi_get_boolean(env, cell_data.bold, &bold);
    _ = c.napi_set_named_property(env, result, "bold", bold);

    var italic: c.napi_value = undefined;
    _ = c.napi_get_boolean(env, cell_data.italic, &italic);
    _ = c.napi_set_named_property(env, result, "italic", italic);

    var faint: c.napi_value = undefined;
    _ = c.napi_get_boolean(env, cell_data.faint, &faint);
    _ = c.napi_set_named_property(env, result, "faint", faint);

    var inverse: c.napi_value = undefined;
    _ = c.napi_get_boolean(env, cell_data.inverse, &inverse);
    _ = c.napi_set_named_property(env, result, "inverse", inverse);

    var invisible: c.napi_value = undefined;
    _ = c.napi_get_boolean(env, cell_data.invisible, &invisible);
    _ = c.napi_set_named_property(env, result, "invisible", invisible);

    var strikethrough: c.napi_value = undefined;
    _ = c.napi_get_boolean(env, cell_data.strikethrough, &strikethrough);
    _ = c.napi_set_named_property(env, result, "strikethrough", strikethrough);

    var underline: c.napi_value = undefined;
    _ = c.napi_create_uint32(env, cell_data.underline, &underline);
    _ = c.napi_set_named_property(env, result, "underline", underline);

    return result;
}

fn terminalGetRow(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    // Get 'this' and arguments
    var argc: usize = 1;
    var args: [1]c.napi_value = undefined;
    var this: c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &args, &this, null) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to parse arguments");
        return null;
    }

    if (argc < 1) {
        _ = c.napi_throw_error(env, null, "Expected 1 argument: row");
        return null;
    }

    // Get the context
    var ctx: ?*TerminalContext = null;
    if (!getTerminalContext(env, this, &ctx)) return null;

    // Get row argument
    var row_u32: u32 = 0;
    if (c.napi_get_value_uint32(env, args[0], &row_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "row must be a number");
        return null;
    }

    const dims = ctx.?.terminal.getScreenDimensions();
    if (row_u32 >= dims.rows) {
        _ = c.napi_throw_error(env, null, "row out of bounds");
        return null;
    }

    // Create array for the row
    var result: c.napi_value = undefined;
    _ = c.napi_create_array_with_length(env, dims.cols, &result);

    // Fill the array with cell data
    var col: u32 = 0;
    while (col < dims.cols) : (col += 1) {
        const cell_ref = ctx.?.terminal.getCellRef(@intCast(col), @intCast(row_u32));
        if (cell_ref) |ref| {
            const cell_data = Terminal.extractCellData(ref);
            const cell_obj = createCellDataObject(env, cell_data);
            _ = c.napi_set_element(env, result, col, cell_obj);
        }
    }

    return result;
}

fn terminalGetRegion(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    // Get 'this' and arguments
    var argc: usize = 4;
    var args: [4]c.napi_value = undefined;
    var this: c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &args, &this, null) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to parse arguments");
        return null;
    }

    if (argc < 4) {
        _ = c.napi_throw_error(env, null, "Expected 4 arguments: startRow, startCol, endRow, endCol");
        return null;
    }

    // Get the context
    var ctx: ?*TerminalContext = null;
    if (!getTerminalContext(env, this, &ctx)) return null;

    // Get arguments
    var start_row_u32: u32 = 0;
    var start_col_u32: u32 = 0;
    var end_row_u32: u32 = 0;
    var end_col_u32: u32 = 0;

    if (c.napi_get_value_uint32(env, args[0], &start_row_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "startRow must be a number");
        return null;
    }
    if (c.napi_get_value_uint32(env, args[1], &start_col_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "startCol must be a number");
        return null;
    }
    if (c.napi_get_value_uint32(env, args[2], &end_row_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "endRow must be a number");
        return null;
    }
    if (c.napi_get_value_uint32(env, args[3], &end_col_u32) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "endCol must be a number");
        return null;
    }

    const dims = ctx.?.terminal.getScreenDimensions();
    if (end_row_u32 >= dims.rows or end_col_u32 >= dims.cols) {
        _ = c.napi_throw_error(env, null, "region out of bounds");
        return null;
    }

    const row_count = end_row_u32 - start_row_u32 + 1;
    const col_count = end_col_u32 - start_col_u32 + 1;

    // Create 2D array
    var result: c.napi_value = undefined;
    _ = c.napi_create_array_with_length(env, row_count, &result);

    // Fill the array with rows
    var row: u32 = start_row_u32;
    while (row <= end_row_u32) : (row += 1) {
        var row_array: c.napi_value = undefined;
        _ = c.napi_create_array_with_length(env, col_count, &row_array);

        var col: u32 = start_col_u32;
        while (col <= end_col_u32) : (col += 1) {
            const cell_ref = ctx.?.terminal.getCellRef(@intCast(col), @intCast(row));
            if (cell_ref) |ref| {
                const cell_data = Terminal.extractCellData(ref);
                const cell_obj = createCellDataObject(env, cell_data);
                _ = c.napi_set_element(env, row_array, col - start_col_u32, cell_obj);
            }
        }

        _ = c.napi_set_element(env, result, row - start_row_u32, row_array);
    }

    return result;
}

fn terminalGetAllCells(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    // Get 'this'
    var this: c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, null, null, &this, null) != c.napi_ok) {
        _ = c.napi_throw_error(env, null, "Failed to get this");
        return null;
    }

    // Get the context
    var ctx: ?*TerminalContext = null;
    if (!getTerminalContext(env, this, &ctx)) return null;

    const dims = ctx.?.terminal.getScreenDimensions();

    // Create 2D array
    var result: c.napi_value = undefined;
    _ = c.napi_create_array_with_length(env, dims.rows, &result);

    // Fill the array with all rows
    var row: u32 = 0;
    while (row < dims.rows) : (row += 1) {
        var row_array: c.napi_value = undefined;
        _ = c.napi_create_array_with_length(env, dims.cols, &row_array);

        var col: u32 = 0;
        while (col < dims.cols) : (col += 1) {
            const cell_ref = ctx.?.terminal.getCellRef(@intCast(col), @intCast(row));
            if (cell_ref) |ref| {
                const cell_data = Terminal.extractCellData(ref);
                const cell_obj = createCellDataObject(env, cell_data);
                _ = c.napi_set_element(env, row_array, col, cell_obj);
            }
        }

        _ = c.napi_set_element(env, result, row, row_array);
    }

    return result;
}
