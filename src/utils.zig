const std = @import("std");
const rm = @import("redismodule");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const ZERO_HASH: [32]u8 = @splat(0);

pub fn check_args_count(ctx: ?*rm.RedisModuleCtx, expected: c_int, argc: c_int) c_int {
    const wrongArity = rm.RedisModule_WrongArity orelse return rm.REDISMODULE_ERR;
    if (argc < expected) {
        return wrongArity(ctx);
    }
    return rm.REDISMODULE_OK;
}

pub fn some(ptr: anytype) @typeInfo(@TypeOf(ptr)).optional.child {
    return ptr orelse unreachable;
}

pub fn hash_node(left: [Sha256.digest_length]u8, right: [Sha256.digest_length]u8) [32]u8 {
    var buf: [2 * Sha256.digest_length]u8 = undefined;
    var out: [Sha256.digest_length]u8 = undefined;
    @memcpy(buf[0..Sha256.digest_length], &left);
    @memcpy(buf[Sha256.digest_length..], &right);

    Sha256.hash(&buf, &out, .{});

    return out;
}
