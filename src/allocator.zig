const std = @import("std");
const rm = @import("redismodule");

pub const redis_allocator = std.mem.Allocator{ .ptr = undefined, .vtable = &redis_vtable };

const redis_vtable = std.mem.Allocator.VTable{
    .alloc = rAlloc,
    .resize = rResize,
    .remap = rRemap,
    .free = rFree,
};

fn rAlloc(_: *anyopaque, len: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
    return @ptrCast(rm.RedisModule_Alloc.?(len));
}
fn rResize(_: *anyopaque, m: []u8, _: std.mem.Alignment, new_len: usize, _: usize) bool {
    return new_len <= m.len;
}
fn rRemap(_: *anyopaque, m: []u8, _: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
    return @ptrCast(rm.RedisModule_Realloc.?(m.ptr, new_len));
}
fn rFree(_: *anyopaque, m: []u8, _: std.mem.Alignment, _: usize) void {
    rm.RedisModule_Free.?(m.ptr);
}
