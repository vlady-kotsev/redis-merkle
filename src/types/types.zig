const std = @import("std");
const rm = @import("redismodule");
const tree_type = @import("merkle_tree//hooks.zig");

pub fn register_types(ctx: *rm.RedisModuleCtx) c_int {
    if (tree_type.register_merkle_tree_type(ctx) != rm.REDISMODULE_OK) {
        return rm.REDISMODULE_ERR;
    }

    return rm.REDISMODULE_OK;
}
