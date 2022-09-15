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

const BoardOptions = struct {
    use_camera: ?CameraOptions = null,
    use_cursor: ?CursorOptions = null,
    const CameraOptions = struct {
        screen_width: u8,
        screen_height: u8,
    };
    const CursorOptions = struct {
        init_x: u8 = 0,
        init_y: u8 = 0,
    };
};

fn Camera(
        cam: BoardOptions.CameraOptions,
        w: u8, h: u8
) type {
    cassert( cam.screen_width <= w,
        "Camera screen_width must be less or equal than width" );
    cassert( cam.screen_height <= h,
        "Camera screen_height must be less or equal than height" );
    return struct {
        const width = w;
        const height = h;
        offx: UFits(w) = cam.screen_width,
        offy: UFits(h) = cam.screen_height,
    };
}

fn Cursor(
        cur: BoardOptions.CursorOptions,
        w: u8, h: u8
) type {
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
        width: u8, height: u8,
        options: BoardOptions,
) type {
    _ = options;
    return struct {
        data: Global_data,
        tiles: [width][height]Tile_data,
        camera: if ( options.use_camera ) |cam|
            Camera(cam, width, height) else void
            = if ( options.use_camera ) |_| .{} else void{},
        cursor: if ( options.use_cursor ) |cur|
            Cursor(cur, width, height) else void
            = if ( options.use_cursor ) |_| .{} else void{},
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
