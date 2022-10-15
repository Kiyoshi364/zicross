const std = @import("std");
const testing = std.testing;

const utils = @import("utils.zig");
const UFits = utils.UFits;

pub const CameraOptions = struct {
    screen_width: u8,
    screen_height: u8,
    start_x: u8 = 0,
    start_y: u8 = 0,
};

pub const CursorOptions = struct {
    init_x: u8 = 0,
    init_y: u8 = 0,
};

pub fn Camera(comptime cam: CameraOptions, comptime w: u8, comptime h: u8) type {
    return struct {
        pub const opts = cam;
        offx: UFits(w) = 0,
        offy: UFits(h) = 0,
    };
}

pub fn Cursor(comptime cur: CursorOptions, comptime w: u8, comptime h: u8) type {
    return struct {
        x: UFits(w) = cur.init_x,
        y: UFits(h) = cur.init_y,
    };
}

pub fn Board(
        comptime Tile_data: type,
        comptime w: u8, comptime h: u8,
) type {
    return struct {
        const Self = @This();
        pub const width = w;
        pub const height = h;

        const init = if ( utils.isInt(Tile_data) ) 0
            else Tile_data{};
        tiles: [height][width]Tile_data
            = [_][width]Tile_data{ [_]Tile_data{ init } ** width } ** height,

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
    const withVoid = Board(void, width, height){};
    const withInt = Board(u8, width, height){};
    const withStruct = Board(struct{ int: u8 = 1 }, width, height){};
    _ = withVoid;
    _ = withInt;
    _ = withStruct;
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
