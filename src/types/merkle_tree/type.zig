const std = @import("std");
const utils = @import("../../utils.zig");

const INIT_CAP: usize = 4;

pub const TreeNode = struct {
    index: usize,
    node_hash: [32]u8,
};

pub const MerkleTree = struct {
    root_hash: [32]u8,
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(TreeNode), // always even
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
        self.nodes.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn get() void {}

    pub fn insert(self: *Self) !void {
        _ = self;
    }

    pub fn delete(self: *Self) !void {
        _ = self;
    }

    pub fn prove_inclusion(self: *Self) void {
        _ = self;
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
        for (self.nodes.items) |node| {
            try level_zero.append(self.allocator, node.node_hash);
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
