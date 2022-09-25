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

pub fn Camera(cam: CameraOptions, w: u8, h: u8) type {
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

pub fn Cursor(cur: CursorOptions, w: u8, h: u8) type {
    return struct {
        const width = w;
        const height = h;
        x: UFits(w) = cur.init_x,
        y: UFits(h) = cur.init_y,
    };
}

pub fn Board(
        comptime Tile_data: type,
        w: u8, h: u8,
) type {
    return struct {
        const Self = @This();
        pub const width = w;
        pub const height = h;

        tiles: [height][width]Tile_data
            = [_][width]Tile_data{ [_]Tile_data{ 0 } ** width } ** height,

        const TileIterConst = struct {
            ptr: *const Self,
            x: u8 = 0,
            y: u8 = 0,

            const Entry = struct {
                tile: Tile_data, x: u8, y: u8,
            };
            pub fn next(self: *@This()) ?Entry {
                if ( self.y >= height ) {
                    return null;
                }
                const ret = .{
                    .tile = self.ptr.tiles[self.y][self.x],
                    .x = self.x,
                    .y = self.y,
                };
                if ( self.x + 1 < width ) {
                    self.*.x += 1;
                } else {
                    self.*.x = 0;
                    self.*.y += 1;
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
                if ( self.y >= height ) {
                    return null;
                }
                const ret = .{
                    .tile = &self.ptr.tiles[self.y][self.x],
                    .x = self.x,
                    .y = self.y,
                };
                if ( self.x + 1 < width ) {
                    self.*.x += 1;
                } else {
                    self.*.x = 0;
                    self.*.y += 1;
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
                if ( self.y >= height ) {
                    return null;
                }
                const ret = .{
                    .tile = &self.ptr.tiles[self.x][self.y],
                    .x = self.x,
                    .y = self.y,
                };
                if ( self.x + 1 < width ) {
                    self.*.x += 1;
                } else {
                    self.*.x = 0;
                    self.*.y += 1;
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

pub const Button = enum(u8) {
    const w4 = @import("wasm4.zig");
    B1 = w4.BUTTON_1,
    B2 = w4.BUTTON_2,
    Left = w4.BUTTON_LEFT,
    Right = w4.BUTTON_RIGHT,
    Up = w4.BUTTON_UP,
    Down = w4.BUTTON_DOWN,
};

pub const ButtonStatus = enum(u2) {
    Released = 0b00,
    Pressed = 0b01,
    Unpressed = 0b10,
    Held = 0b11,
};

fn join(old: u1, new: u1) u2 {
    return (@as(u2, old) << 1) | @as(u2, new);
}

fn isFlagSet(bits: u8, flag: u8) u1 {
    return @boolToInt(bits & flag == flag);
}

pub fn checkInput(old_pad: u8, new_pad: u8) [6]ButtonStatus {
    const buttons = [_]u8{
        @enumToInt(Button.Up),   @enumToInt(Button.Left),
        @enumToInt(Button.Down), @enumToInt(Button.Right),
        @enumToInt(Button.B1),   @enumToInt(Button.B2),
    };
    var bs: [6]ButtonStatus = undefined;
    for (buttons) |b, i| {
        bs[i] = @intToEnum(ButtonStatus, join(
                isFlagSet(old_pad, b), isFlagSet(new_pad, b)));
    }
    return bs;
}

test "It compiles!" {
    testing.refAllDeclsRecursive(@This());
}
