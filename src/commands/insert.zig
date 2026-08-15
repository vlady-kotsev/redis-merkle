const rm = @import("redismodule");
const utils = @import("../utils.zig");
const Cmd = @import("command.zig").Cmd;
const MerkleTree = @import("../types//merkle_tree/type.zig").MerkleTree;
const HashCollector = @import("../helpers/hash_collector.zig").HashCollector;
const redis_allocator = @import("../allocator.zig").redis_allocator;
const common = @import("common.zig");

pub const INSERT_CMD: Cmd = .{
    .name = "MT.INSERT",
    .flags = "write",
    .first_key = 1,
    .last_key = 2,
    .step = 1,
    .cb = mt_insert_cmd,
};

fn mt_insert_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
    const status: c_int = utils.check_args_count(ctx, 3, argc);
    if (status != rm.REDISMODULE_OK) {
        return status;
    }

    const mt_key = rm.RedisModule_OpenKey.?(ctx, argv[1], rm.REDISMODULE_WRITE | rm.REDISMODULE_READ) orelse return rm.RedisModule_ReplyWithNull.?(ctx);
    defer rm.RedisModule_CloseKey.?(mt_key);

    const hash_key = rm.RedisModule_OpenKey.?(ctx, argv[2], rm.REDISMODULE_READ) orelse return rm.RedisModule_ReplyWithNull.?(ctx);
    defer rm.RedisModule_CloseKey.?(hash_key);

    var tree = common.get_or_create_merke_tree(mt_key) catch return rm.RedisModule_ReplyWithError.?(ctx, "ERR get or create tree");

    switch (rm.RedisModule_KeyType.?(hash_key)) {
        rm.REDISMODULE_KEYTYPE_EMPTY => return rm.RedisModule_ReplyWithNull.?(ctx),
        rm.REDISMODULE_KEYTYPE_HASH => {
            var hash_collector = HashCollector.init(redis_allocator) catch return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to allocate hash collector");
            defer hash_collector.deinit();

            hash_collector.calcualte_hash(hash_key) catch return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to generate sha");
            tree.insert(hash_collector.result_hash) catch return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to insert in tree");
            _ = rm.RedisModule_SignalModifiedKey.?(ctx, argv[1]);
        },

        else => return rm.RedisModule_ReplyWithError.?(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE),
    }

    return rm.RedisModule_ReplyWithLongLong.?(ctx, @intCast(tree.nodes.items.len));
}
