const std = @import("std");
const testing = std.testing;

fn cassert(comptime ok: bool, comptime err: []const u8) void {
    if (!ok) @compileError(err);
}

fn ufits(i: usize) u16 {
    return @clz(u32, @as(usize, 0)) - @clz(u32, i);
}

fn UFits(i: usize) type {
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

pub const CameraOptions = struct {
    screen_width: u8,
    screen_height: u8,
};

pub const CursorOptions = struct {
    init_x: u8 = 0,
    init_y: u8 = 0,
};

pub const BoardOptions = struct {
    use_camera: ?CameraOptions = null,
    use_cursor: ?CursorOptions = null,
};

fn Camera(cam: CameraOptions, w: u8, h: u8) type {
    cassert( cam.screen_width <= w,
        "Camera screen_width must be less or equal than width" );
    cassert( cam.screen_height <= h,
        "Camera screen_height must be less or equal than height" );
    return struct {
        const width = w;
        const height = h;
        offx: UFits(w) = 0,
        offy: UFits(h) = 0,
    };
}

fn Cursor(cur: CursorOptions, w: u8, h: u8) type {
    return struct {
        const width = w;
        const height = h;
        x: UFits(w) = cur.init_x,
        y: UFits(h) = cur.init_y,
    };
}

pub fn Board(
        comptime Global_data: type,
        comptime Tile_data: type,
        w: u8, h: u8,
        options: BoardOptions,
) type {
    _ = options;
    return struct {
        const Self = @This();
        const width = w;
        const height = h;

        data: Global_data,
        tiles: [width][height]Tile_data,
        camera: if ( options.use_camera ) |cam|
            Camera(cam, width, height) else void
            = if ( options.use_camera ) |_| .{} else void{},
        cursor: if ( options.use_cursor ) |cur|
            Cursor(cur, width, height) else void
            = if ( options.use_cursor ) |_| .{} else void{},

        const TileIterConst = struct {
            ptr: *const Self,
            x: u8 = 0,
            y: u8 = 0,

            const Entry = struct {
                tile: Tile_data, x: u8, y: u8,
            };
            pub fn next(self: *@This()) ?Entry {
                const ret = .{
                    .tile = self.ptr.tiles[self.x][self.y],
                    .x = self.x,
                    .y = self.y,
                };
                if ( self.x + 1 < width ) {
                    self.*.x += 1;
                } else {
                    if ( self.y + 1 < height ) {
                        self.*.x = 0;
                        self.*.y += 1;
                    } else {
                        return null;
                    }
                }
                return ret;
            }
        };

        pub fn tileIter(self: *const Self) TileIterConst {
            return .{ .ptr = self, };
        }

        const TileIterConstRef = struct {
            ptr: *const Self,
            x: u8 = 0,
            y: u8 = 0,

            const Entry = struct {
                tile: *const Tile_data, x: u8, y: u8,
            };
            pub fn next(self: *@This()) ?Entry {
                const ret = .{
                    .tile = &self.ptr.tiles[self.x][self.y],
                    .x = self.x,
                    .y = self.y,
                };
                if ( self.x + 1 < width ) {
                    self.*.x += 1;
                } else {
                    if ( self.y + 1 < height ) {
                        self.*.x = 0;
                        self.*.y += 1;
                    } else {
                        return null;
                    }
                }
                return ret;
            }
        };

        pub fn tileIterConstRef(self: *const Self) TileIterConstRef {
            return .{ .ptr = self, };
        }

        const TileIterRef = struct {
            ptr: *Self,
            x: u8 = 0,
            y: u8 = 0,

            const Entry = struct {
                tile: *Tile_data, x: u8, y: u8,
            };
            pub fn next(self: *@This()) ?Entry {
                const ret = .{
                    .tile = &self.ptr.tiles[self.x][self.y],
                    .x = self.x,
                    .y = self.y,
                };
                if ( self.x + 1 < width ) {
                    self.*.x += 1;
                } else {
                    if ( self.y + 1 < height ) {
                        self.*.x = 0;
                        self.*.y += 1;
                    } else {
                        return null;
                    }
                }
                return ret;
            }
        };

        pub fn tileIterRef(self: *Self) TileIterRef {
            return .{ .ptr = self, };
        }
    };
}

test "Board example" {
    const width = 4;
    const height = 4;
    const a = Board(void, void, width, height, .{
        .use_camera = if (true) .{
            .screen_width = 2,
            .screen_height = 2,
        } else null,
    }){
        .data = void{},
        .tiles = [_][height]void{ [_]void{ void{} } ** height } ** width,
    };
    _ = a;
}

test "It compiles!" {
    testing.refAllDeclsRecursive(@This());
}
