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
        "Ptr_tinfo must be an uint type");
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

            fn writeBefore(self: *const Header,
                    buf: []u8, index: Index) void {
                utils.writeBefore(Header, self, buf, index);
            }

            fn readBefore(buf: []const u8, index: Index) Header {
                return utils.readBefore(Header, buf, index);
            }
        };

        fn Frame(comptime T: type) type {
            return struct {
                frame: FrameCnt,
                ptr: Ptr(T),

                fn writeBefore(self: *const @This(),
                        buf: []u8, index: Index) void {
                    utils.writeBefore(@This(), self, buf, index);
                }

                fn readBefore(buf: []const u8, index: Index) @This() {
                    return utils.readBefore(@This(), buf, index);
                }
            };
        }

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
                    "Unsupported type for infering typeInfo: `"
                    ++ @typeName(T) ++ "`"),
            };
        }

        fn typeInfoPackedStruct(comptime T: type,
                comptime stct: std.builtin.Type.Struct) TypeInfo {
            if ( stct.layout != .Packed ) {
                @compileError("Infering typeInfo is only supported for packet structs: "
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
                                    ++ high_data_name
                                    ++ "` in struct `"
                                    ++ @typeName(T) ++ "`");
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
                                    ++ high_data_name
                                    ++ "` in struct `"
                                    ++ @typeName(T) ++ "`");
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

        pub const CreateError = error { OutOfMemory };

        pub fn unsafeCreate(self: *Self, tinfo: TypeInfo,
                thing: *const anyopaque) CreateError!Ptr(anyopaque) {
            if ( tinfo.size() == 0 ) {
                return @as(Ptr(anyopaque), undefined);
            }
            const base = calcBase(
                self.curr_end, tinfo, config.padding);
            if( base.end >= blen ) {
                return CreateError.OutOfMemory;
            }
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

        pub fn explicitCreate(self: *Self, comptime T: type,
                tinfo: TypeInfo, thing: T) CreateError!Ptr(T) {
            assert( typeCheck(T, tinfo) );
            const ptr = try self.unsafeCreate(tinfo, &thing);
            return Ptr(T).fromIndex(ptr.toIndex());
        }

        pub fn create(self: *Self,
                comptime T: type, thing: T) CreateError!Ptr(T) {
            return self.explicitCreate(T, self.typeInfo(T), thing);
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

        fn calcPreFrameIndex(self: Self, comptime State: type,
                frame_idx: FrameCnt) Index {
            const F = Frame(State);
            return @as(Index, self.buffer.len)
                - @sizeOf(F) * frame_idx;
        }

        pub fn advanceFrame(self: *Self, comptime State: type,
                state: State) CreateError!Ptr(State) {
            const old_end = self.curr_end;
            const F = Frame(State);
            const preFrameIndex
                = self.calcPreFrameIndex(State, self.frameCnt);
            const statePtr = try self.create(State, state);
            if ( self.curr_end + @sizeOf(F) > preFrameIndex ) {
                self.*.curr_end = old_end;
                return CreateError.OutOfMemory;
            }
            const new_frame = F{
                .frame = self.curr_frame,
                .ptr = statePtr,
            };
            new_frame.writeBefore(&self.buffer, preFrameIndex);
            self.*.curr_frame += 1;
            self.*.frameCnt += 1;
            return statePtr;
        }

        pub fn getFrame(self: *const Self, comptime State: type,
                frameNum: FrameCnt) Ptr(State) {
            assert( self.curr_frame > frameNum );
            const frameBack = self.curr_frame - frameNum;
            assert( frameBack <= self.frameCnt );
            const frame_idx = self.frameCnt - frameBack;
            const preFrameIndex
                = self.calcPreFrameIndex(State, frame_idx);
            const frame = Frame(State)
                .readBefore(&self.buffer, preFrameIndex);
            return frame.ptr;
        }

        pub fn getFrameBack(self: *const Self, comptime State: type,
                frameBack: FrameCnt) Ptr(State) {
            return self.getFrame(State, self.curr_frame - frameBack - 1);
        }

        pub fn getLastFrame(self: *const Self,
                comptime State: type) Ptr(State) {
            return self.getFrameBack(State, 0);
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

test "PureBuffer create Example" {
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

    copy(u8, test_buffer[26..32], &.{ 7, 1, 2, 0, 2, 1 });
    const b2ref = try pb.create(B, b);
    const b2ptr = pb.deref(b2ref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(b, b2ptr.*);
    try testing.expectEqual(c, cptr.*);
    try testing.expectEqual(d, dptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);
}

test "PureBuffer advanceFrame example" {
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
    const State = packed struct {
        int8: i8,
        uint8: u8,
        uint16: u16,
        refA: PB.Ptr(A),
        refB: PB.Ptr(B),
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

    const state1 = State{
        .int8 = -1,
        .uint8 = 10,
        .uint16 = 0x0304,
        .refA = aref,
        .refB = bref,
    };
    const state1ref = try pb.advanceFrame(State, state1);
    const state1ptr = pb.deref(state1ref);
    copy(u8, test_buffer[11..23], &.{ 7, 1, 4, 4, 0xFF, 10, 4, 3,
        @intCast(u8, aref.toIndex() & 0xFF),
        @intCast(u8, aref.toIndex() >> 8),
        @intCast(u8, bref.toIndex() & 0xFF),
        @intCast(u8, bref.toIndex() >> 8),
    });
    copy(u8, test_buffer[0x3FC..0x400], &.{ 7, 1,
        @intCast(u8, state1ref.toIndex() & 0xFF),
        @intCast(u8, state1ref.toIndex() >> 8),
    });
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(state1, state1ptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);

    // New frame
    const a2 = @as(u8, 70);

    copy(u8, test_buffer[23..28], &.{ 8, 1, 1, 0, 70 });
    const a2ref = try pb.create(A, a2);
    const a2ptr = pb.deref(a2ref);
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(state1, state1ptr.*);
    try testing.expectEqual(a2, a2ptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);

    const state2 = State{
        .int8 = state1.int8,
        .uint8 = state1.uint8,
        .uint16 = state1.uint16,
        .refA = a2ref,
        .refB = state1.refB,
    };

    const state2ref = try pb.advanceFrame(State, state2);
    const state2ptr = pb.deref(state2ref);
    copy(u8, test_buffer[28..40], &.{ 8, 1, 4, 4, 0xFF, 10, 4, 3,
        @intCast(u8, a2ref.toIndex() & 0xFF),
        @intCast(u8, a2ref.toIndex() >> 8),
        @intCast(u8, bref.toIndex() & 0xFF),
        @intCast(u8, bref.toIndex() >> 8),
    });
    copy(u8, test_buffer[0x3F8..0x3FC], &.{ 8, 1,
        @intCast(u8, state2ref.toIndex() & 0xFF),
        @intCast(u8, state2ref.toIndex() >> 8),
    });
    try testing.expectEqual(a, aptr.*);
    try testing.expectEqual(b, bptr.*);
    try testing.expectEqual(state1, state1ptr.*);
    try testing.expectEqual(a2, a2ptr.*);
    try testing.expectEqual(state2, state2ptr.*);
    try testing.expectEqualSlices(u8, &test_buffer, buf);

    try testing.expectEqual(state1ref, pb.getFrame(State, 0x0107));
    try testing.expectEqual(state1ref, pb.getFrameBack(State, 1));

    try testing.expectEqual(state2ref, pb.getFrame(State, 0x0108));
    try testing.expectEqual(state2ref, pb.getFrameBack(State, 0));
    try testing.expectEqual(state2ref, pb.getLastFrame(State));
}

test "It compiles!" {
    testing.refAllDeclsRecursive(@This());
    testing.refAllDeclsRecursive(PureBuffer(.{}));
}
