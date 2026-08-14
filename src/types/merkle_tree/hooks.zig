const std = @import("std");
const t = @import("type.zig");
const MerkleTree = t.MerkleTree;
const TreeNode = t.TreeNode;
const redis_allocator = @import("../../allocator.zig").redis_allocator;
const rm = @import("redismodule");
const utils = @import("../../utils.zig");
const some = utils.some;
const state = @import("../../state.zig");

const HASH_LEN = std.crypto.hash.sha2.Sha256.digest_length;

fn freeValue(value: ?*anyopaque) callconv(.c) void {
    const tree: *MerkleTree = @ptrCast(@alignCast(value orelse return));
    tree.deinit();
}

fn rdbSave(io: ?*rm.RedisModuleIO, value: ?*anyopaque) callconv(.c) void {
    const tree: *MerkleTree = @ptrCast(@alignCast(value.?));
    rm.RedisModule_SaveUnsigned.?(io, tree.nodes.items.len);
    for (tree.nodes.items) |*h| {
        const node_hash = h.node_hash;
        rm.RedisModule_SaveStringBuffer.?(io, &node_hash, node_hash.len);
    }
}

fn memUsage(value: ?*const anyopaque) callconv(.c) usize {
    const tree: *const MerkleTree = @ptrCast(@alignCast(value.?));
    var total = @sizeOf(MerkleTree) + tree.nodes.items.len * HASH_LEN;
    for (tree.levels.items) |lvl| total += lvl.items.len * HASH_LEN;
    return total;
}

fn rdbLoad(io: ?*rm.RedisModuleIO, encver: c_int) callconv(.c) ?*anyopaque {
    if (encver != 0) return null;

    var tree = t.MerkleTree.init(redis_allocator) catch return null;

    const n = rm.RedisModule_LoadUnsigned.?(io);
    tree.nodes.ensureTotalCapacity(redis_allocator, n) catch return null;

    var i: u64 = 0;
    while (i < n) : (i += 1) {
        var len: usize = undefined;
        const buf = rm.RedisModule_LoadStringBuffer.?(io, &len);
        defer rm.RedisModule_Free.?(buf);
        if (len != 32) return null;
        var node: TreeNode = .{ .index = i, .node_hash = undefined };
        @memcpy(&node.node_hash, buf[0..32]);
        tree.nodes.appendAssumeCapacity(node);
    }

    tree.rebuild() catch return null;
    return tree;
}

fn digest(md: ?*rm.RedisModuleDigest, value: ?*anyopaque) callconv(.c) void {
    const tree: *MerkleTree = @ptrCast(@alignCast(value.?));
    const root = tree.root_hash;
    some(rm.RedisModule_DigestAddStringBuffer)(md, &root, root.len);
    some(rm.RedisModule_DigestEndSequence)(md);
}

fn aofRewrite(aof: ?*rm.RedisModuleIO, key: ?*rm.RedisModuleString, value: ?*anyopaque) callconv(.c) void {
    const tree: *MerkleTree = @ptrCast(@alignCast(value orelse return));

    for (tree.nodes.items) |*leaf| {
        some(rm.RedisModule_EmitAOF)(
            aof,
            "MERKLE.ADD",
            "sb",
            key,
            leaf.node_hash[0..],
            leaf.node_hash.len,
        );
    }
}

pub fn register_merkle_tree_type(ctx: *rm.RedisModuleCtx) c_int {
    var tm = std.mem.zeroes(rm.RedisModuleTypeMethods);
    tm.version = rm.REDISMODULE_TYPE_METHOD_VERSION;
    tm.rdb_save = rdbSave;
    tm.free = freeValue;
    tm.rdb_load = rdbLoad;
    tm.mem_usage = memUsage;
    tm.digest = digest;
    tm.aof_rewrite = aofRewrite;
    // tm.copy = copyValue;

    state.merkle_type = some(rm.RedisModule_CreateDataType)(ctx, "mrkltree1", 0, &tm);
    if (state.merkle_type == null) {
        return rm.REDISMODULE_ERR;
    }

    return rm.REDISMODULE_OK;
}
