const rm = @import("redismodule");
const mt = @import("../types//merkle_tree/type.zig");
const MerkleTree = mt.MerkleTree;

const redis_allocator = @import("../allocator.zig").redis_allocator;

pub fn get_or_create_merke_tree(key: ?*rm.RedisModuleKey) !*MerkleTree {
    return switch (rm.RedisModule_KeyType.?(key)) {
        rm.REDISMODULE_KEYTYPE_EMPTY => blk: {
            const tree = try MerkleTree.init(redis_allocator);
            errdefer tree.deinit();

            if (rm.RedisModule_ModuleTypeSetValue.?(key, mt.merkle_type, tree) == rm.REDISMODULE_ERR) {
                return error.SetValueFailed;
            }
            break :blk tree;
        },
        rm.REDISMODULE_KEYTYPE_MODULE => blk: {
            if (rm.RedisModule_ModuleTypeGetType.?(key) != mt.merkle_type) return error.WrongType;
            break :blk @ptrCast(@alignCast(rm.RedisModule_ModuleTypeGetValue.?(key)));
        },
        else => error.WrongType,
    };
}
