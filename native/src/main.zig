const std = @import("std");

const c = @cImport({
    @cInclude("node_api.h");
});

export fn napi_register_module_v1(env: c.napi_env, exports: c.napi_value) c.napi_value {
    // Example: Register a simple function
    var func: c.napi_value = undefined;
    _ = c.napi_create_function(env, null, 0, exampleFunction, null, &func);
    _ = c.napi_set_named_property(env, exports, "example", func);

    return exports;
}

fn exampleFunction(env: c.napi_env, info: c.napi_callback_info) callconv(.c) c.napi_value {
    _ = info;
    var result: c.napi_value = undefined;

    // TODO: Call your Zig library functions here
    // const value = your_lib.doSomething();

    _ = c.napi_create_string_utf8(env, "Hello from Zig!", 16, &result);
    return result;
}
