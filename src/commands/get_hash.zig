const std = @import("std");
const rm = @import("redismodule");
const utils = @import("../utils.zig");
const Cmd = @import("command.zig").Cmd;
const mt = @import("../types/merkle_tree/tree.zig");
const MerkleTree = mt.MerkleTree;
const HashCollector = @import("../helpers/hash_collector.zig").HashCollector;
const redis_allocator = @import("../allocator.zig").redis_allocator;

pub const GET_HASH_CMD: Cmd = .{
    .name = "MT.HASH",
    .flags = "readonly",
    .first_key = 1,
    .last_key = 1,
    .step = 1,
    .cb = mt_get_hash_cmd,
};

fn mt_get_hash_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
    const status: c_int = utils.check_args_count(ctx, 2, argc);
    if (status != rm.REDISMODULE_OK) {
        return status;
    }

    const hash_key = rm.RedisModule_OpenKey.?(ctx, argv[1], rm.REDISMODULE_READ) orelse return rm.RedisModule_ReplyWithNull.?(ctx);
    defer rm.RedisModule_CloseKey.?(hash_key);

    switch (rm.RedisModule_KeyType.?(hash_key)) {
        rm.REDISMODULE_KEYTYPE_EMPTY => return rm.RedisModule_ReplyWithNull.?(ctx),
        rm.REDISMODULE_KEYTYPE_HASH => {
            var hash_collector = HashCollector.init(redis_allocator) catch return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to allocate hash collector");
            defer hash_collector.deinit();

            hash_collector.calcualte_hash(hash_key) catch return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to generate sha");

            const hex = std.fmt.bytesToHex(hash_collector.result_hash, .upper);
            return rm.RedisModule_ReplyWithSimpleString.?(ctx, &hex);
        },

        else => return rm.RedisModule_ReplyWithError.?(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE),
    }

    return rm.RedisModule_ReplyWithError.?(ctx, "ERR failed to delete node in tree");
}
