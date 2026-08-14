const std = @import("std");
const rm = @import("redismodule");
const some = @import("utils.zig").some;
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const SHA_HEX_LEN: c_int = 64;
const INIT_CAP = 4;

pub const RedisHashCollector = struct {
    allocator: std.mem.Allocator,
    buf: std.ArrayList(u8) = .empty,
    err: ?anyerror = null,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
    ) !Self {
        return .{
            .allocator = allocator,
            .buf = try std.ArrayList(u8).initCapacity(allocator, INIT_CAP),
        };
    }

    pub fn deinit(self: *Self) void {
        self.buf.deinit(self.allocator);
    }

    pub fn generate_hex(self: *Self, hash_key: ?*rm.RedisModuleKey) ![SHA_HEX_LEN]u8 {
        self.buf.clearRetainingCapacity();
        self.err = null;

        try self.collect_all_entries(hash_key);
        return sha256hex(self.buf);
    }

    fn collect_all_entries(self: *Self, hash_key: ?*rm.RedisModuleKey) !void {
        const cursor = some(rm.RedisModule_ScanCursorCreate)();
        defer some(rm.RedisModule_ScanCursorDestroy)(cursor);

        while (some(rm.RedisModule_ScanKey)(hash_key, cursor, get_hash_field_cb, self) != 0) {
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

        const ptr = some(rm.RedisModule_StringPtrLen)(str, &len);
        try self.buf.appendSlice(self.allocator, ptr[0..len]);
    }
};

fn get_hash_field_cb(
    _: ?*rm.RedisModuleKey,
    field: ?*rm.RedisModuleString,
    value: ?*rm.RedisModuleString,
    privdata: ?*anyopaque,
) callconv(.c) void {
    const c: *RedisHashCollector = @ptrCast(@alignCast(privdata.?));
    c.append_string(field) catch |e| {
        c.err = e;
        return;
    };
    c.append_string(value) catch |e| {
        c.err = e;
        return;
    };
}

pub fn sha256hex(buf: std.ArrayList(u8)) [SHA_HEX_LEN]u8 {
    var out: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(buf.items, &out, .{});

    return std.fmt.bytesToHex(out, .lower);
}
