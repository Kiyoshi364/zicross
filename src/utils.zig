const std = @import("std");
const testing = std.testing;

pub fn cassert(comptime ok: bool, comptime err: []const u8) void {
    if (!ok) @compileError(err);
}

pub inline fn todo() noreturn {
    @panic("TODO: Not implemented!");
}

pub inline fn ctodo() noreturn {
    @compileError("Comptime TODO: Not implemented!");
}

pub fn ufits(i: usize) u16 {
    return @clz(@as(usize, 0)) - @clz(i);
}

pub fn UFits(comptime i: usize) type {
    const bits = ufits(i);
    return @Type(.{ .Int = .{
        .signedness = .unsigned,
        .bits = bits,
    }});
}

test "UFits hardcoded" {
    try testing.expectEqual(u0, UFits(0));
    try testing.expectEqual(u1, UFits(1));
    try testing.expectEqual(u2, UFits(2));
    try testing.expectEqual(u3, UFits(4));
    try testing.expectEqual(u7, UFits(0x7F));
    try testing.expectEqual(u8, UFits(0x80));
}

test "UFits up until u16" {
    const u_max = u16;
    var i = @as(u_max, 0);
    var bits = @as(u16, 0);
    var next_inc = @as(u_max, 1);
    while ( true ) {
        try testing.expectEqual(bits, ufits(i));

        // std.debug.print("0x{x:0>4}: {d} bits\n", .{ i, bits });
        if ( @addWithOverflow(u_max, i, 1, &i) ) {
            break;
        } else {
            if ( i == next_inc ) {
                bits += 1;
                next_inc = next_inc << 1;
            }
        }
    }
}

pub fn ufitsUp(i: usize) u16 {
    const bits = ufits(i);
    return switch( bits ) {
        0         => 0,
        1  ... 8  => 8,
        9  ... 16 => 16,
        17 ... 32 => 32,
        33 ... 64 => 64,
        else      => @panic("ufitsUp: more than 64 bits unhandled"),
    };
}

pub fn UFitsUp(comptime i: usize) type {
    const bits = ufitsUp(i);
    return @Type(.{ .Int = .{
        .signedness = .unsigned,
        .bits = bits,
    }});
}

test "UFitsUp hardcoded" {
    try testing.expectEqual(u0, UFitsUp(0));
    try testing.expectEqual(u8, UFitsUp(1));
    try testing.expectEqual(u8, UFitsUp(2));
    try testing.expectEqual(u8, UFitsUp(4));
    try testing.expectEqual(u8, UFitsUp(0x7F));
    try testing.expectEqual(u8, UFitsUp(0x80));
    try testing.expectEqual(u8, UFitsUp(0xFF));
    try testing.expectEqual(u16, UFitsUp(0x100));
    try testing.expectEqual(u16, UFitsUp(0xFFFF));
    try testing.expectEqual(u32, UFitsUp(0x10000));
}

pub fn isInt(comptime T: type) bool {
    return @typeInfo(T) == .Int;
}

pub fn isUint(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .Int and info.Int.signedness == .unsigned;
}

pub fn writeBefore(comptime T: type, thing: *const T,
        buf: []u8, index: usize) void {
    const size = @sizeOf(T);
    const begin = index - size;
    const self_slice
        = @as([]const u8, @ptrCast(*const [size]u8, thing));
    std.mem.copy(u8, buf[begin..index], self_slice);
}

pub fn readBefore(comptime T: type,
        buf: []const u8, index: usize) T {
    const size = @sizeOf(T);
    const begin = index - size;
    return @ptrCast(*align(1) const T, &buf[begin]).*;
}

test "It compiles!" {
    testing.refAllDeclsRecursive(@This());
}
