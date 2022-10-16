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

pub const BufferConfig = struct {
    blen: usize = 1024,

    Data_tinfo: type = u8,
    Ptr_tinfo: type = u8,
    ptrType: PtrType = .index,

    padding: Padding = .none,
};

pub fn PureBuffer(comptime config: BufferConfig) type {
    const blen = config.blen;
    const Index = utils.UFitsUp(blen);
    const FrameCnt = utils.UFitsUp(blen);
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
        curr_end: Index = 0,
        curr_frame: FrameCnt = 0,
        /// how many frames are stored at the back of the buffer
        frameCnt: FrameCnt = 0,
        buffer: [blen]u8 = .{ 0 } ** blen,

        const Self = @This();

        const Header = struct {
            frame: FrameCnt,
            info: TypeInfo,

            const size = @sizeOf(Header);

            fn writeBefore(self: *const Header,
                    buf: []u8, index: Index) void {
                const begin = index - size;
                const self_slice
                    = @as([]const u8, @ptrCast(*const [size]u8, self));
                std.mem.copy(u8, buf[begin..index], self_slice);
            }

            fn readBefore(buf: []const u8, index: Index) Header {
                const begin = index - size;
                return @ptrCast(*align(1) const Header, &buf[begin]).*;
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
            if ( @sizeOf(T) == 0 ) {
                return .{ .data = 0, .ptr = 0, };
            }
            const info = @typeInfo(T);
            return switch (info) {
                .Int => |int| .{
                    .data = (int.bits + 7) / 8,
                    .ptr = 0,
                },
                .Struct => |stct| typeInfoPackedStruct(T, stct),
                else => @compileError(
                    "Unsupported type: " ++ @typeName(T) ),
            };
        }

        fn typeInfoPackedStruct(comptime T: type,
                comptime stct: std.builtin.Type.Struct) TypeInfo {
            if ( stct.layout != .Packed ) {
                @compileError("Non-packet struct not supported: "
                    ++ @typeName(T));
            }
            comptime {
                var highest_data = @as(?config.Data_tinfo, null);
                var high_data_name = @as([]const u8, undefined);
                var lowest_ptr = @as(?config.Ptr_tinfo, null);
                var low_ptr_name = @as([]const u8, undefined);
                var highest_ptr = @as(?config.Ptr_tinfo, null);
                inline for (stct.fields) |field| {
                    const f_type = field.field_type;
                    const addrBegin = @bitOffsetOf(T, field.name);
                    const addrEnd = addrBegin + @bitSizeOf(f_type);
                    if ( isPtr(f_type) ) {
                        if ( lowest_ptr ) |low| {
                            if ( addrBegin < low ) {
                                lowest_ptr = addrBegin;
                                low_ptr_name = field.name;
                            }
                            assert( highest_ptr != null );
                            if ( highest_ptr.? < addrEnd ) {
                                highest_ptr = addrEnd;
                            }
                        } else {
                            lowest_ptr = addrBegin;
                            low_ptr_name = field.name;
                            assert( highest_ptr == null );
                            highest_ptr = addrEnd;
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
                        if ( highest_data ) |high| {
                            if ( addrEnd > high ) {
                                highest_data = addrEnd;
                                high_data_name = field.name;
                            }
                        } else {
                            highest_data = addrEnd;
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
                    const ptr = @divExact(highest_ptr.?, 8) - data;
                    return .{
                        .data = data,
                        .ptr = ptr,
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

        pub fn unsafeCreate(self: *Self,
                tinfo: TypeInfo, thing: *const anyopaque) !Ptr(anyopaque) {
            if ( tinfo.size() == 0 ) {
                return @as(Ptr(anyopaque), undefined);
            }
            const base = calcBase(
                self.curr_end, tinfo, config.padding);
            assert( base.end < blen );
            const buf = &self.buffer;
            const header = Header{
                .frame = self.curr_frame,
                .info = tinfo,
            };
            header.writeBefore(buf, base.begin);
            const thing_size = tinfo.size();
            const thing_slice
                = @intToPtr([*]const u8, @ptrToInt(thing))
                    [0..thing_size];
            std.mem.copy(u8, buf[base.begin..base.end], thing_slice);
            self.curr_end = base.end;
            return Ptr(anyopaque).fromIndex(base.begin);
        }

        pub fn explicitCreate(self: *Self,
                comptime T: type, tinfo: TypeInfo, thing: T) !Ptr(T) {
            assert( typeCheck(T, tinfo) );
            const ptr = try self.unsafeCreate(tinfo, @ptrCast(*const anyopaque, &thing));
            return Ptr(T).fromIndex(ptr.toIndex());
        }

        pub fn create(self: *Self, comptime T: type, thing: T) !Ptr(T) {
            return self.explicitCreate(T, typeInfoFn(T).?, thing);
        }

        pub fn deref(self: *const Self,
                ref: anytype) *align(1) const @TypeOf(ref).typ {
            const T = @TypeOf(ref).typ;
            const buf = &self.buffer;
            const index = ref.toIndex();
            const tinfo = Header.readBefore(buf, index).info;
            assert( index + tinfo.size() <= self.curr_end );
            const thing_ptr = &buf[index];
            return @ptrCast(*align(1) const T, thing_ptr);
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

test "typeInfoPackedStruct" {
    const PB = PureBuffer(.{});
    const C = packed struct {
        int8: i8 = -1,
        uint16: u16 = 0x0304,
        int8_2: i8 = -2,
    };
    const D = packed struct {
        int8: i8 = -3,
        ref: PB.Ptr(C),
    };
    const expCtinfo = PB.TypeInfo{
        .data = 4,
        .ptr = 0,
    };
    const expDtinfo = PB.TypeInfo{
        .data = 1,
        .ptr = 2,
    };

    const ctinfo = PB.typeInfoPackedStruct(C, @typeInfo(C).Struct);
    const dtinfo = PB.typeInfoPackedStruct(D, @typeInfo(D).Struct);
    try testing.expectEqual(expCtinfo, ctinfo);
    try testing.expectEqual(expDtinfo, dtinfo);
}

test "PureBuffer Example" {
    const PB = PureBuffer(.{});
    var test_buffer = [_]u8{0} ** 1024;
    var pb = PB{
        .curr_frame = 0x0107,
    };
    const buf = &pb.buffer;

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
    const D = packed struct {
        int8: i8 = -3,
        ref: PB.Ptr(C),
    };

    const copy = std.mem.copy;
    copy(u8, test_buffer[0..5], &.{ 7, 1, 1, 0, 35 });
    const aref = try pb.create(A, a);
    const aptr = pb.deref(aref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);

    copy(u8, test_buffer[5..11], &.{ 7, 1, 2, 0, 2, 1 });
    const bref = try pb.create(B, b);
    const bptr = pb.deref(bref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);

    copy(u8, test_buffer[11..19], &.{ 7, 1, 4, 0, 255, 4, 3, 254 });
    const cref = try pb.create(C, c);
    const cptr = pb.deref(cref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(c, cptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);

    const d = D{ .ref = cref };

    copy(u8, test_buffer[19..26], &.{ 7, 1, 1, 2, 253, 15, 0 });
    const dref = try pb.create(D, d);
    const dptr = pb.deref(dref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(c, cptr.*);
    try testing.expectEqual(d, dptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);

    std.mem.copy(u8, test_buffer[26..32], &.{ 7, 1, 2, 0, 2, 1 });
    const b2ref = try pb.create(B, b);
    const b2ptr = pb.deref(b2ref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(b, b2ptr.*);
    try testing.expectEqual(c, cptr.*);
    try testing.expectEqual(d, dptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);
}

test "It compiles!" {
    testing.refAllDeclsRecursive(@This());
}
