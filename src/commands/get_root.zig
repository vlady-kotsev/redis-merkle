const rm = @import("redismodule");
const utils = @import("../utils.zig");
const some = utils.some;
const Cmd = @import("command.zig").Cmd;
const state = @import("../state.zig");
const MerkleTree = @import("../types//merkle_tree/type.zig").MerkleTree;
const redis_hash = @import("../hash.zig");

pub const GET_ROOT_CMD: Cmd = .{
    .name = "MT.ROOT",
    .flags = "readonly",
    .first_key = 1,
    .last_key = 1,
    .step = 1,
    .cb = mt_get_root_cmd,
};

fn mt_get_root_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
    const status: c_int = utils.check_args_count(ctx, 2, argc);
    if (status != rm.REDISMODULE_OK) {
        return status;
    }

    const key = some(rm.RedisModule_OpenKey)(ctx, argv[1], rm.REDISMODULE_READ) orelse return some(rm.RedisModule_ReplyWithNull)(ctx);
    defer some(rm.RedisModule_CloseKey)(key);

    switch (some(rm.RedisModule_KeyType)(key)) {
        rm.REDISMODULE_KEYTYPE_EMPTY => return some(rm.RedisModule_ReplyWithNull)(ctx),
        rm.REDISMODULE_KEYTYPE_MODULE => {
            if (rm.RedisModule_ModuleTypeGetType.?(key) != state.merkle_type)
                return rm.RedisModule_ReplyWithError.?(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE);
            const tree: *MerkleTree = @ptrCast(@alignCast(rm.RedisModule_ModuleTypeGetValue.?(key)));

            return some(rm.RedisModule_ReplyWithString)(ctx, some(rm.RedisModule_CreateString)(ctx, &tree.root_hash, redis_hash.SHA_HEX_LEN));
        },

        else => return some(rm.RedisModule_ReplyWithError)(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE),
    }

    return rm.REDISMODULE_ERR;
}
