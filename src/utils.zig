const std = @import("std");
const rm = @import("redismodule");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const ZERO_HASH: [32]u8 = @splat(0);

pub fn check_args_count(ctx: ?*rm.RedisModuleCtx, expected: c_int, argc: c_int) c_int {
    if (argc != expected) {
        _ = rm.RedisModule_WrongArity.?(ctx);
        return rm.REDISMODULE_ERR;
    }
    return rm.REDISMODULE_OK;
}

pub fn hash_node(left: [Sha256.digest_length]u8, right: [Sha256.digest_length]u8) [32]u8 {
    var buf: [2 * Sha256.digest_length]u8 = undefined;
    var out: [Sha256.digest_length]u8 = undefined;
    @memcpy(buf[0..Sha256.digest_length], &left);
    @memcpy(buf[Sha256.digest_length..], &right);

    Sha256.hash(&buf, &out, .{});

    return out;
}
