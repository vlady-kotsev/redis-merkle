const rm = @import("redismodule");
const utils = @import("../utils.zig");
const Cmd = @import("command.zig").Cmd;
const mt = @import("../types/merkle_tree/tree.zig");
const MerkleTree = mt.MerkleTree;
const HashCollector = @import("../helpers/hash_collector.zig").HashCollector;
const redis_allocator = @import("../allocator.zig").redis_allocator;

pub const DELETE_CMD: Cmd = .{
    .name = "MT.DELETE",
    .flags = "write",
    .first_key = 1,
    .last_key = 2,
    .step = 1,
    .cb = mt_delete_cmd,
};

fn mt_delete_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
    const status: c_int = utils.check_args_count(ctx, 3, argc);
    if (status != rm.REDISMODULE_OK) {
        return status;
    }

    const mt_key = rm.RedisModule_OpenKey.?(ctx, argv[1], rm.REDISMODULE_WRITE | rm.REDISMODULE_READ) orelse return rm.RedisModule_ReplyWithNull.?(ctx);
    defer rm.RedisModule_CloseKey.?(mt_key);

    const hash_key = rm.RedisModule_OpenKey.?(ctx, argv[2], rm.REDISMODULE_READ) orelse return rm.RedisModule_ReplyWithNull.?(ctx);
    defer rm.RedisModule_CloseKey.?(hash_key);

    switch (rm.RedisModule_KeyType.?(mt_key)) {
        rm.REDISMODULE_KEYTYPE_EMPTY => {
            return rm.RedisModule_ReplyWithNull.?(ctx);
        },
        rm.REDISMODULE_KEYTYPE_MODULE => {
            if (rm.RedisModule_ModuleTypeGetType.?(mt_key) != mt.merkle_type) {
                return rm.RedisModule_ReplyWithError.?(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE);
            }
            const tree: *MerkleTree = @ptrCast(@alignCast(rm.RedisModule_ModuleTypeGetValue.?(mt_key)));

            switch (rm.RedisModule_KeyType.?(hash_key)) {
                rm.REDISMODULE_KEYTYPE_EMPTY => return rm.RedisModule_ReplyWithNull.?(ctx),
                rm.REDISMODULE_KEYTYPE_HASH => {
                    var hash_collector = HashCollector.init(redis_allocator) catch return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to allocate hash collector");
                    defer hash_collector.deinit();

                    hash_collector.calcualte_hash(hash_key) catch return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to generate sha");
                    tree.delete(hash_collector.result_hash) catch return rm.RedisModule_ReplyWithNull.?(ctx);
                    _ = rm.RedisModule_SignalModifiedKey.?(ctx, argv[1]);

                    if (tree.nodes.items.len == 0) {
                        if (rm.RedisModule_DeleteKey.?(mt_key) == rm.REDISMODULE_ERR) {
                            return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to delete empty tree key");
                        }
                        return rm.RedisModule_ReplyWithLongLong.?(ctx, 0);
                    }

                    return rm.RedisModule_ReplyWithLongLong.?(ctx, @intCast(tree.nodes.items.len));
                },

                else => return rm.RedisModule_ReplyWithError.?(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE),
            }
        },
        else => return rm.RedisModule_ReplyWithError.?(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE),
    }

    return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to delete node in tree");
}
