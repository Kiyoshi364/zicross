const std = @import("std");
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
    const BufIndex = utils.UfitsUp(bcnt);
    const Index = utils.UfitsUp(blen);
    const FrameCnt = utils.UfitsUp(blen);
    cassert( bcnt >= 3, "bcnt must be at least 3");
    cassert( utils.isUint(config.Data_tinfo),
        "Data_tinfo must be an uint type");
    cassert( utils.isUint(config.Ptr_tinfo),
        "Data_tinfo must be an uint type");
    const VoidPtr = switch ( config.ptrType ) {
        .ptr => utils.ctodo(),
        .index => Index,
        .relPtr => utils.ctodo(),
    };
    return struct {
        curr_buf: BufIndex,
        curr_end: Index,
        curr_frame: FrameCnt,
        frameCnt: FrameCnt,
        buffers: [bcnt][blen]u8,

        const Self = @This();

        const Header = struct {
            frame: FrameCnt,
            info: TypeInfo,
        };

        pub const TypeInfo = struct {
            data: config.Data_tinfo,
            ptr: config.Ptr_tinfo,
            // alig: if ( config.padding == .manual ) u29 else void,
        };

        pub fn Ptr(comptime T: type) type {
            return struct {
                typ: type = T,
                index: VoidPtr,
            };
        }

        pub fn typeInfo(comptime T: type) TypeInfo {
            const info = @typeInfo(T);
            return switch (info) {
                else => @compileError(
                    "Unsupported type: " ++ @typeName(T) ),
            };
        }

        fn typeCheck(comptime T: type, tinfo: TypeInfo) bool {
            const info = typeInfo(T);
            return info.data == tinfo.data and info.ptr == tinfo.ptr;
        }

        fn calcBase(end: Index, frameCnt: FrameCnt, tinfo: TypeInfo, pad: Padding) Index {
            return switch ( pad ) {
                .infered => utils.ctodo(),
                .manual  => utils.ctodo(),
                .none => {
                    _ = end;
                    _ = frameCnt;
                    _ = tinfo;
                },
            };
        }

        pub fn create(self: *Self,
                comptime T: type, tinfo: TypeInfo, thing: T) !Ptr(T) {
            assert( typeCheck(T, tinfo) );
            const base
                = calcBase(self.curr_end, self.frameCnt, tinfo);
            _ = base;
            _ = thing;
            return Ptr(T){};
        }
    };
}
