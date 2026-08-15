const std = @import("std");
const rm = @import("redismodule");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const HashCollector = struct {
    allocator: std.mem.Allocator,
    buf: std.ArrayList(u8) = .empty,
    err: ?anyerror = null,
    result_hash: [32]u8 = undefined,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
    ) !Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buf.deinit(self.allocator);
    }

    pub fn calcualte_hash(self: *Self, hash_key: ?*rm.RedisModuleKey) !void {
        self.buf.clearRetainingCapacity();
        self.err = null;

        try self.collect_all_entries(hash_key);
        self.calculate();
    }

    fn calculate(self: *Self) void {
        Sha256.hash(self.buf.items, &self.result_hash, .{});
    }

    fn collect_all_entries(self: *Self, hash_key: ?*rm.RedisModuleKey) !void {
        const cursor = rm.RedisModule_ScanCursorCreate.?();
        defer rm.RedisModule_ScanCursorDestroy.?(cursor);

        while (rm.RedisModule_ScanKey.?(hash_key, cursor, get_hash_field_cb, self) != 0) {
            if (self.err) |err| {
                return err;
            }
        }
        if (self.err) |err| {
            return err;
        }
    }

    fn append_string(self: *Self, s: ?*rm.RedisModuleString) !void {
        const str = s orelse return;
        var len: usize = undefined;

        const ptr = rm.RedisModule_StringPtrLen.?(str, &len);
        try self.buf.appendSlice(self.allocator, ptr[0..len]);
    }
};

fn get_hash_field_cb(
    _: ?*rm.RedisModuleKey,
    field: ?*rm.RedisModuleString,
    value: ?*rm.RedisModuleString,
    privdata: ?*anyopaque,
) callconv(.c) void {
    const c: *HashCollector = @ptrCast(@alignCast(privdata.?));
    c.append_string(field) catch |e| {
        c.err = e;
        return;
    };
    c.append_string(value) catch |e| {
        c.err = e;
        return;
    };
}
