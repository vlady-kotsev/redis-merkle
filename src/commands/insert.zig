const rm = @import("redismodule");
const utils = @import("../utils.zig");
const some = utils.some;
const Cmd = @import("command.zig").Cmd;

pub const INSERT_CMD: Cmd = .{
    .name = "MT.INSERT",
    .flags = "write",
    .first_key = 1,
    .last_key = 2,
    .step = 1,
    .cb = mt_insert_cmd,
};

fn mt_insert_cmd(ctx: ?*rm.RedisModuleCtx, argv: [*c]?*rm.RedisModuleString, argc: c_int) callconv(.c) c_int {
    _ = argc;
    _ = argv;

    return some(rm.RedisModule_ReplyWithNull)(ctx);
}
