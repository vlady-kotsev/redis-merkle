const std = @import("std");
const rm = @import("redismodule");
const utils = @import("../utils.zig");
const Cmd = @import("command.zig").Cmd;
const mt = @import("../types//merkle_tree/tree.zig");
const MerkleTree = mt.MerkleTree;
const hash_helpers = @import("../helpers/hash_collector.zig");

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

    const key = rm.RedisModule_OpenKey.?(ctx, argv[1], rm.REDISMODULE_READ) orelse return rm.RedisModule_ReplyWithNull.?(ctx);
    defer rm.RedisModule_CloseKey.?(key);

    switch (rm.RedisModule_KeyType.?(key)) {
        rm.REDISMODULE_KEYTYPE_EMPTY => return rm.RedisModule_ReplyWithNull.?(ctx),
        rm.REDISMODULE_KEYTYPE_MODULE => {
            if (rm.RedisModule_ModuleTypeGetType.?(key) != mt.merkle_type) {
                return rm.RedisModule_ReplyWithError.?(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE);
            }
            const tree: *MerkleTree = @ptrCast(@alignCast(rm.RedisModule_ModuleTypeGetValue.?(key)));

            const hex = std.fmt.bytesToHex(tree.root_hash, .upper);
            const hex_string = rm.RedisModule_CreateString.?(ctx, &hex, hex.len);
            defer rm.RedisModule_FreeString.?(ctx, hex_string);

            return rm.RedisModule_ReplyWithString.?(ctx, hex_string);
        },

        else => return rm.RedisModule_ReplyWithError.?(ctx, rm.REDISMODULE_ERRORMSG_WRONGTYPE),
    }

    return rm.REDISMODULE_ERR;
}
