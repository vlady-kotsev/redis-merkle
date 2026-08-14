const rm = @import("redismodule");

pub const Cmd = struct {
    name: [:0]const u8,
    flags: [:0]const u8,
    first_key: c_int,
    last_key: c_int,
    step: c_int,
    cb: fn (ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int,
};
