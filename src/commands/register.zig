const std = @import("std");
const rm = @import("redismodule");
const utils = @import("../utils.zig");

const redis_allocator = @import("../allocator.zig").redis_allocator;
const INSERT_CMD = @import("insert.zig").INSERT_CMD;
const GET_ROOT_CMD = @import("get_root.zig").GET_ROOT_CMD;
const DELETE_CMD = @import("delete.zig").DELETE_CMD;
const PROOFS_CMD = @import("get_proofs.zig").GET_PROOFS_CMD;
const GET_HASH_CMD = @import("get_hash.zig").GET_HASH_CMD;

pub fn register_cmds(ctx: ?*rm.RedisModuleCtx) c_int {
    if (rm.RedisModule_CreateCommand.?(
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

    if (rm.RedisModule_CreateCommand.?(
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

    if (rm.RedisModule_CreateCommand.?(
        ctx,
        DELETE_CMD.name,
        DELETE_CMD.cb,
        DELETE_CMD.flags,
        DELETE_CMD.first_key,
        DELETE_CMD.last_key,
        DELETE_CMD.step,
    ) != rm.REDISMODULE_OK) {
        return rm.REDISMODULE_ERR;
    }

    if (rm.RedisModule_CreateCommand.?(
        ctx,
        PROOFS_CMD.name,
        PROOFS_CMD.cb,
        PROOFS_CMD.flags,
        PROOFS_CMD.first_key,
        PROOFS_CMD.last_key,
        PROOFS_CMD.step,
    ) != rm.REDISMODULE_OK) {
        return rm.REDISMODULE_ERR;
    }

    if (rm.RedisModule_CreateCommand.?(
        ctx,
        GET_HASH_CMD.name,
        GET_HASH_CMD.cb,
        GET_HASH_CMD.flags,
        GET_HASH_CMD.first_key,
        GET_HASH_CMD.last_key,
        GET_HASH_CMD.step,
    ) != rm.REDISMODULE_OK) {
        return rm.REDISMODULE_ERR;
    }

    return rm.REDISMODULE_OK;
}

// fn mt_delete_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
//     _ = argc;
//     _ = argv;

//     return some(rm.RedisModule_ReplyWithNull)(ctx);
// }

// fn mt_prove_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
//     _ = argc;
//     _ = argv;

//     return some(rm.RedisModule_ReplyWithNull)(ctx);
// }
