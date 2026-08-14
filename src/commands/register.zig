const std = @import("std");
const rm = @import("redismodule");
const utils = @import("../utils.zig");
const some = utils.some;

const redis_allocator = @import("../allocator.zig").redis_allocator;
const INSERT_CMD = @import("insert.zig").INSERT_CMD;
const GET_ROOT_CMD = @import("get_root.zig").GET_ROOT_CMD;

pub fn register_cmds(ctx: ?*rm.RedisModuleCtx) c_int {
    if (some(rm.RedisModule_CreateCommand)(
        ctx,
        GET_ROOT_CMD.name,
        GET_ROOT_CMD.cb,
        GET_ROOT_CMD.flags,
        GET_ROOT_CMD.first_key,
        GET_ROOT_CMD.last_key,
        GET_ROOT_CMD.step,
    ) != rm.REDISMODULE_OK) {
        return rm.REDISMODULE_ERR;
    }

    if (some(rm.RedisModule_CreateCommand)(
        ctx,
        INSERT_CMD.name.ptr,
        INSERT_CMD.cb,
        INSERT_CMD.flags.ptr,
        INSERT_CMD.first_key,
        INSERT_CMD.last_key,
        INSERT_CMD.step,
    ) != rm.REDISMODULE_OK) {
        return rm.REDISMODULE_ERR;
    }

    // if (some(rm.RedisModule_CreateCommand)(ctx, "MT.DELETE", mt_delete_cmd, "write", 1, 1, 1) != rm.REDISMODULE_OK) {
    //     return rm.REDISMODULE_ERR;
    // }
    // if (some(rm.RedisModule_CreateCommand)(ctx, "MT.PROVE", mt_prove_cmd, "readonly", 1, 1, 1) != rm.REDISMODULE_OK) {
    //     return rm.REDISMODULE_ERR;
    // }

    return rm.REDISMODULE_OK;
}

fn mt_delete_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
    _ = argc;
    _ = argv;

    return some(rm.RedisModule_ReplyWithNull)(ctx);
}

fn mt_prove_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
    _ = argc;
    _ = argv;

    return some(rm.RedisModule_ReplyWithNull)(ctx);
}
