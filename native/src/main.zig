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
