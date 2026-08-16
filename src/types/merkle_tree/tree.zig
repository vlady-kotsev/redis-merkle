const std = @import("std");
const utils = @import("../../utils.zig");
const rm = @import("redismodule");
const INIT_CAP: usize = 4;

pub var merkle_type: ?*rm.RedisModuleType = null;

pub const NodePos = enum(u8) {
    Left = 0,
    Right = 1,
};

pub const MerkleNode = struct {
    hash: [32]u8,
    pos: NodePos,
};

pub const MerkleTree = struct {
    root_hash: [32]u8,
    allocator: std.mem.Allocator,
    nodes: std.ArrayList([32]u8),
    levels: std.ArrayList(std.ArrayList(MerkleNode)),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const tree_ptr = try allocator.create(MerkleTree);
        tree_ptr.* = .{
            .allocator = allocator,
            .nodes = try .initCapacity(allocator, INIT_CAP),
            .levels = try .initCapacity(allocator, INIT_CAP),
            .root_hash = utils.ZERO_HASH,
        };
        return tree_ptr;
    }

    pub fn deinit(self: *Self) void {
        for (self.levels.items) |*level| {
            level.deinit(self.allocator);
        }
        self.levels.deinit(self.allocator);
        self.nodes.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn insert(self: *Self, node_hash: [32]u8) !void {
        try self.nodes.append(self.allocator, node_hash);
        try self.rebuild();
    }

    pub fn delete(self: *Self, node_hash: [32]u8) !void {
        const hash_index = try self.find_index(node_hash);
        _ = self.nodes.swapRemove(hash_index);
        try self.rebuild();
    }

    pub fn get_proves(self: *Self, node_hash: [32]u8) !std.ArrayList([33]u8) {
        const leaf_index = try self.find_index(node_hash);

        var proofs: std.ArrayList([33]u8) = .empty;
        errdefer proofs.deinit(self.allocator);

        if (self.levels.items.len > 1) {
            try proofs.ensureTotalCapacity(self.allocator, self.levels.items.len - 1);

            var idx = leaf_index;
            var depth: usize = 0;
            while (depth < self.levels.items.len - 1) : (depth += 1) {
                const level = self.levels.items[depth].items;
                const sibling = idx ^ 1;
                var current_proof: [33]u8 = undefined;

                // set left/right flag
                current_proof[0] = if (sibling & 1 == 1) @intFromEnum(NodePos.Right) else @intFromEnum(NodePos.Left);

                if (sibling < level.len) {
                    @memcpy(current_proof[1..], &level[sibling].hash);
                } else {
                    @memcpy(current_proof[1..], &utils.ZERO_HASH);
                }

                proofs.appendAssumeCapacity(current_proof);
                idx /= 2;
            }
        }

        return proofs;
    }

    fn find_index(self: *const Self, hash: [32]u8) !usize {
        var i: usize = 0;
        while (i < self.nodes.items.len) : (i += 1) {
            if (std.mem.eql(u8, &self.nodes.items[i], &hash)) {
                break;
            }
        }
        if (i == self.nodes.items.len) {
            return error.MerkleTreeItemNotFound;
        }
        return i;
    }

    pub fn rebuild(self: *Self) !void {
        for (self.levels.items) |*level| {
            level.deinit(self.allocator);
        }
        self.levels.clearRetainingCapacity();

        if (self.nodes.items.len == 0) {
            self.root_hash = utils.ZERO_HASH;
            return;
        }
        var level_zero: std.ArrayList(MerkleNode) = .empty;
        errdefer level_zero.deinit(self.allocator);
        for (self.nodes.items, 0..) |node_hash, i| {
            const node: MerkleNode = .{ .hash = node_hash, .pos = if (i % 2 == 0) NodePos.Left else NodePos.Right };
            try level_zero.append(self.allocator, node);
        }

        try self.levels.append(self.allocator, level_zero);

        var i: usize = 0;
        while (self.levels.items[i].items.len > 1) : (i += 1) {
            const current = self.levels.items[i].items;

            var next: std.ArrayList(MerkleNode) = .empty;
            errdefer next.deinit(self.allocator);

            try next.ensureTotalCapacity(self.allocator, (current.len + 1) / 2);

            var j: usize = 0;
            while (j + 1 < current.len) : (j += 2) {
                const new_node_pos: NodePos = if (next.items.len % 2 == 0) .Left else .Right;
                const new_node: MerkleNode = .{
                    .hash = utils.hash_node(current[j].hash, current[j + 1].hash),
                    .pos = new_node_pos,
                };
                next.appendAssumeCapacity(new_node);
            }
            if (j < current.len) {
                const new_node_pos: NodePos = if (next.items.len % 2 == 0) .Left else .Right;
                const new_node: MerkleNode = .{
                    .hash = utils.hash_node(current[j].hash, utils.ZERO_HASH),
                    .pos = new_node_pos,
                };
                next.appendAssumeCapacity(new_node);
            }

            try self.levels.append(self.allocator, next);
        }

        self.root_hash = self.levels.items[i].items[0].hash;
    }
};
