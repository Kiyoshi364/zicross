const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

const utils = @import("utils.zig");

const cassert = utils.cassert;

pub const PtrType = enum {
    ptr, index, relPtr
};

pub const Padding = enum {
    none, infered, manual
};

pub const Config = struct {
    blen: usize = 1024,
    bcnt: usize = 3,

    Data_tinfo: type = u8,
    Ptr_tinfo: type = u8,
    ptrType: PtrType = .index,

    padding: Padding = .none,
};

pub fn PG(comptime config: Config) type {
    const blen = config.blen;
    const bcnt = config.bcnt;
    const BufIndex = utils.UFitsUp(bcnt);
    const Index = utils.UFitsUp(blen);
    const FrameCnt = utils.UFitsUp(blen);
    cassert( bcnt >= 3, "bcnt must be at least 3");
    cassert( utils.isUint(config.Data_tinfo),
        "Data_tinfo must be an uint type");
    cassert( utils.isUint(config.Ptr_tinfo),
        "Data_tinfo must be an uint type");
    const VoidPtr = switch ( config.ptrType ) {
        .ptr => utils.ctodo(),
        .index => packed struct {
            i: Index,
            fn fromIndex(index: Index) @This() {
                return .{ .i = index, };
            }
            fn toIndex(self: @This()) Index {
                return self.i;
            }
        },
        .relPtr => utils.ctodo(),
    };
    return struct {
        curr_buf: BufIndex = 0,
        curr_end: Index = 0,
        curr_frame: FrameCnt = 0,
        /// how many frames are stored at the back of the buffer
        frameCnt: [bcnt]FrameCnt = .{ 0 } ** bcnt,
        buffers: [bcnt][blen]u8 = .{ .{ 0 } ** blen} ** bcnt,

        const Self = @This();

        const Header = struct {
            frame: FrameCnt,
            info: TypeInfo,

            const size = @sizeOf(Header);

            fn writeBefore(self: *const Header,
                    buf: []u8, index: Index) void {
                const begin = index - size;
                const self_slice
                    = @as([]const u8, @ptrCast(*[size]u8, self));
                std.mem.copy(u8, buf[begin..index], self_slice);
            }

            fn readBefore(buf: []const u8, index: Index) Header {
                const begin = index - size;
                return @ptrCast(*Header, &buf[begin]).*;
            }
        };

        pub const TypeInfo = struct {
            data: config.Data_tinfo,
            ptr: config.Ptr_tinfo,
            // alig: if ( config.padding == .manual ) u29 else void,

            fn size(self: TypeInfo) Index {
                return self.data + self.ptr;
            }
        };

        pub fn Ptr(comptime T: type) type {
            return packed struct {
                const typ = T;
                index: VoidPtr,

                fn fromIndex(index: Index) @This() {
                    return .{ .index = VoidPtr.fromIndex(index) };
                }

                fn toIndex(self: @This()) Index {
                    return self.index.toIndex();
                }
            };
        }

        fn isPtr(comptime T: type) bool {
            return @typeInfo(T) == .Struct
                and @hasDecl(T, "typ") and @hasField(T, "index");
        }

        pub fn typeInfo(self: Self, comptime T: type) TypeInfo {
            _ = self;
            return typeInfoFn(T)
                orelse @panic("TypeInfo under debuging");
        }

        pub fn typeInfoFn(comptime T: type) ?TypeInfo {
            const info = @typeInfo(T);
            return switch (info) {
                .Int => |int| .{
                    .data = (int.bits + 7) / 8,
                    .ptr = 0,
                },
                .Struct => null,
                    // |stct| typeInfoStruct(T, stct),
                else => @compileError(
                    "Unsupported type: " ++ @typeName(T) ),
            };
        }

        fn typeInfoStruct(comptime T: type,
                comptime stct: std.builtin.TypeInfo.Struct) TypeInfo {
            if ( stct.layout != .Packed ) {
                @compileError("Non-packet struct not supported: "
                    ++ @typeName(T));
            }
            comptime {
            var highest_data = @as(?config.Data_tinfo, null);
            var high_data_name = @as([]const u8, undefined);
            var lowest_ptr = @as(?config.Data_tinfo, null);
            var low_ptr_name = @as([]const u8, undefined);
            inline for (stct.fields) |field| {
                const f_type = field.field_type;
                const addr = @bitOffsetOf(T, field.name);
                if ( isPtr(f_type) ) {
                    if ( lowest_ptr ) |low| {
                        if ( addr < low ) {
                            lowest_ptr = addr;
                            low_ptr_name = field.name;
                        }
                    } else {
                        lowest_ptr = addr;
                        low_ptr_name = field.name;
                    }
                    if ( highest_data ) |high| {
                        if ( high < lowest_ptr.? ) {
                            @compileError(
                                "Struct fields are not ordered: `"
                                ++ low_ptr_name
                                ++ "` starts before `"
                                ++ high_data_name ++ "`");
                        }
                    }
                } else {
                    const addr2 = addr + @bitSizeOf(f_type);
                    if ( highest_data ) |high| {
                        if ( addr > high ) {
                            highest_data = addr2;
                            high_data_name = field.name;
                        }
                    } else {
                        highest_data = addr2;
                        high_data_name = field.name;
                    }
                    if ( lowest_ptr ) |low| {
                        if ( highest_data.? < low ) {
                            @compileError(
                                "Struct fields are not ordered: `"
                                ++ low_ptr_name
                                ++ "` starts before `"
                                ++ high_data_name ++ "`");
                        }
                    }
                }
            }
            if ( lowest_ptr ) |low| {
                assert( low % 8 == 0 );
                const data = @divExact(low, 8);
                return .{
                    .data = data,
                    .ptr = @sizeOf(T) - data,
                };
            } else {
                return .{
                    .data = @sizeOf(T),
                    .ptr = 0,
                };
            }
            }
        }

        fn typeCheck(comptime T: type, tinfo: TypeInfo) bool {
            const info = typeInfoFn(T) orelse return true;
            return info.data == tinfo.data and info.ptr == tinfo.ptr;
        }

        const Base = struct {
            base: Index, begin: Index, end: Index,
        };

        fn calcBase(end: Index, tinfo: TypeInfo, pad: Padding) Base {
            return switch ( pad ) {
                .infered => utils.todo(),
                .manual  => utils.todo(),
                .none => blk: {
                    const begin = end + @sizeOf(Header);
                    const thingSize = tinfo.data + tinfo.ptr;
                    break :blk .{
                        .base = end,
                        .begin = begin,
                        .end = begin + thingSize,
                    };
                },
            };
        }

        pub fn create(self: *Self,
                comptime T: type, tinfo: TypeInfo, thing: T) !Ptr(T) {
            assert( typeCheck(T, tinfo) );
            const base = calcBase(
                self.curr_end, tinfo, config.padding);
            assert( base.end < blen );
            const buf = self.active_buf();
            const header = Header{
                .frame = self.curr_frame,
                .info = tinfo,
            };
            header.writeBefore(buf, base.begin);
            const thing_size = tinfo.size();
            const thing_slice
                = @intToPtr([*]const u8, @ptrToInt(&thing))
                    [0..thing_size];
            std.mem.copy(u8, buf[base.begin..base.end], thing_slice);
            self.curr_end = base.end;
            return Ptr(T).fromIndex(base.begin);
        }

        pub fn deref(self: *const Self,
                ref: anytype) *const @TypeOf(ref).typ {
            const T = @TypeOf(ref).typ;
            const buf = self.active_buf_const();
            const index = ref.toIndex();
            const tinfo = Header.readBefore(buf, index).info;
            assert( index + tinfo.size() <= self.curr_end );
            const thing_ptr = &buf[index];
            return @ptrCast(*const T, thing_ptr);
        }

        fn active_buf(self: *Self) []u8 {
            return &self.buffers[self.curr_buf];
        }

        fn active_buf_const(self: *const Self) []const u8 {
            return &self.buffers[self.curr_buf];
        }
    };
}

fn print(buf: []u8) void {
    for (buf) |c, i| {
        const sep: u8 =
            if ( i%0x10 == 0 and i != 0 )
                ';' else ' ';
        std.debug.print("{c}{d}", .{
            sep, c,
        });
    }
}

test "PG Example" {
    const GC = PG(.{});
    var gc = GC{
        .curr_frame = 0x0107,
    };
    const a = @as(u8, 35);
    const A = @TypeOf(a);
    const b = @as(u16, 0x0102);
    const B = @TypeOf(b);
    const C = packed struct {
        int8: i8 = -1,
        uint16: u16 = 0x0304,
        int8_2: i8 = -2,
    };
    const c = C{};

    const aref = try gc.create(A, gc.typeInfo(A), a);
    const aptr = gc.deref(aref);
    try testing.expectEqual(a, aptr.*);

    const buf = gc.active_buf();

    const bref = try gc.create(B, gc.typeInfo(B), b);
    const bptr = gc.deref(bref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);

    // TODO: fix typeInfoStruct
    const ctinfo = .{
        .data = 4,
        .ptr = 0,
    };
    // const ctinfo = gc.typeInfo(C);
    const cref = try gc.create(C, ctinfo, c);
    const cptr = gc.deref(cref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(c, cptr.*);

    const D = packed struct {
        int8: i8 = -3,
        ref: GC.Ptr(C),
    };
    const d = D{ .ref = cref };


    // TODO: fix typeInfoStruct
    const dtinfo = .{
        .data = 1,
        .ptr = 2,
    };
    // const dtinfo = gc.typeInfo(D);
    const dref = try gc.create(D, dtinfo, d);
    const dptr = gc.deref(dref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(c, cptr.*);
    try testing.expectEqual(d, dptr.*);

    std.debug.print("\n", .{});
    print(buf[0..0x28]);
    std.debug.print("\n", .{});
    std.debug.print("buff: {*}\n", .{ buf });
    std.debug.print("a: {} {*}\n", .{ aref.toIndex(), aptr});
    std.debug.print("b: {} {*}\n", .{ bref.toIndex(), bptr});
    std.debug.print("c: {} {*}\n", .{ cref.toIndex(), cptr});
    std.debug.print("d: {} {*}\n", .{ dref.toIndex(), dptr});

    const b2ref = try gc.create(B, gc.typeInfo(B), b);
    const b2ptr = gc.deref(b2ref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(b, b2ptr.*);
    try testing.expectEqual(c, cptr.*);
    try testing.expectEqual(d, dptr.*);

    std.debug.print("\n", .{});
    print(buf[0..0x28]);
    std.debug.print("\n", .{});
    std.debug.print("buff: {*}\n", .{ buf });
    std.debug.print("a: {} {*}\n", .{ aref.toIndex(), aptr});
    std.debug.print("b: {} {*}\n", .{ bref.toIndex(), bptr});
    std.debug.print("c: {} {*}\n", .{ cref.toIndex(), cptr});
    std.debug.print("d: {} {*}\n", .{ dref.toIndex(), dptr});
    std.debug.print("b2: {} {*}\n", .{ b2ref.toIndex(), bptr});
}

test "It compiles!" {
    testing.refAllDeclsRecursive(@This());
}
