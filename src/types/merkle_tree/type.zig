const std = @import("std");
const utils = @import("../../utils.zig");
const rm = @import("redismodule");
const INIT_CAP: usize = 4;

pub var merkle_type: ?*rm.RedisModuleType = null;

pub const MerkleTree = struct {
    root_hash: [32]u8,
    allocator: std.mem.Allocator,
    nodes: std.ArrayList([32]u8),
    levels: std.ArrayList(std.ArrayList([32]u8)),

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

    pub fn get_proves(self: *Self, node_hash: [32]u8) !std.ArrayList([32]u8) {
        if (self.levels.items.len == 1) {
            return .empty;
        }

        const hash_index = try self.find_index(node_hash);
        var proofs = try std.ArrayList([32]u8).initCapacity(
            self.allocator,
            self.levels.items.len - 1,
        );

        // Append siubling on same level
        try proofs.append(self.allocator, self.levels.items[0].items[1]);

        // Go to the root collecting siblings
        var depth: usize = 1;
        var prev_level_index = hash_index;
        while (depth < self.levels.items.len - 1) {
            const parent_index = (prev_level_index / 2);
            const sibling_parent_index = if (parent_index % 2 == 0) (parent_index + 1) else (parent_index - 1);

            try proofs.append(self.allocator, self.levels.items[depth].items[sibling_parent_index]);

            prev_level_index = parent_index;
            depth += 1;
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
        var level_zero: std.ArrayList([32]u8) = .empty;
        errdefer level_zero.deinit(self.allocator);
        for (self.nodes.items) |node_hash| {
            try level_zero.append(self.allocator, node_hash);
        }

        try self.levels.append(self.allocator, level_zero);

        var i: usize = 0;
        while (self.levels.items[i].items.len > 1) : (i += 1) {
            const current = self.levels.items[i].items;

            var next: std.ArrayList([32]u8) = .empty;
            errdefer next.deinit(self.allocator);

            try next.ensureTotalCapacity(self.allocator, (current.len + 1) / 2);

            var j: usize = 0;
            while (j + 1 < current.len) : (j += 2) {
                next.appendAssumeCapacity(utils.hash_node(current[j], current[j + 1]));
            }
            if (j < current.len) {
                next.appendAssumeCapacity(utils.hash_node(current[j], utils.ZERO_HASH));
            }

            try self.levels.append(self.allocator, next);
        }

        self.root_hash = self.levels.items[i].items[0];
    }
};
