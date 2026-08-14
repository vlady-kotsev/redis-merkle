const rm = @import("redismodule");
const cmds = @import("commands/register.zig");
const types = @import("types//types.zig");

const MODULE_NAME = "MT";

export fn RedisModule_OnLoad(ctx: *rm.RedisModuleCtx, _: **rm.RedisModuleString, _: c_int) callconv(.c) c_int {
    if (rm.RedisModule_Init(ctx, MODULE_NAME, 1, rm.REDISMODULE_APIVER_1) == rm.REDISMODULE_ERR) {
        return rm.REDISMODULE_ERR;
    }

    if (types.register_types(ctx) != rm.REDISMODULE_OK) {
        return rm.REDISMODULE_ERR;
    }

    if (cmds.register_cmds(ctx) != rm.REDISMODULE_OK) {
        return rm.REDISMODULE_ERR;
    }

    return rm.REDISMODULE_OK;
}
