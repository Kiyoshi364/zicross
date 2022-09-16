const w4 = @import("wasm4.zig");

const board = @import("board.zig");

const SCREEN_WIDTH = 160;
const SCREEN_HEIGHT = 160;

const tilesize = 9;

const Tile = u2;
const boardWidth = 32;
const boardHeight = boardWidth;

const cam_opts = board.CameraOptions{
    .screen_width = 160 / tilesize,
    .screen_height = 160 / tilesize,
};
const cur_opts = board.CursorOptions{
    .init_x = 5,
    .init_y = 7,
};
const Board = board.Board(void, Tile, boardWidth, boardHeight, .{
    .use_camera = cam_opts,
    .use_cursor = cur_opts,
});
var globalBoard: Board = undefined;

export fn start() void {
    const debug = @import("builtin").mode == .Debug;
    if ( debug ) {
        w4.tone(262 | (253 << 16), 60, 30, w4.TONE_PULSE1 | w4.TONE_MODE3);
    }
    globalBoard = Board{
        .data = {},
        .tiles = [_][boardHeight]Tile{ [_]Tile{ 0 } ** boardHeight } ** boardWidth,
    };

    {
        var iter = globalBoard.tileIterRef();
        while (iter.next()) |triple| {
            const x = triple.x;
            const y = triple.y;
            triple.tile.* = @intCast(Tile, (x+y)%3 + 1);
        }
    }
}

export fn update() void {
    w4.DRAW_COLORS.* = 2;
    w4.text("Hello from Zig!", 10, 10);

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 4;
    }

    drawBoard();
}

fn drawBoard() void {
    drawTiles();
    drawCursor();
}

fn drawCursor() void {
    const cursor = globalBoard.cursor;
    const camera = globalBoard.camera;
    const posx = tilesize * (@as(i32, cursor.x)-@as(i32, camera.offx));
    const posy = tilesize * (@as(i32, cursor.y)-@as(i32, camera.offy));

    const thirdSize = (tilesize-2)/3;
    const halfTSize = thirdSize/2;

    const endposx = posx + tilesize - thirdSize;
    const endposy = posy + tilesize - thirdSize;

    w4.DRAW_COLORS.* = 4;

    w4.rect(posx+1, posy+1, thirdSize, halfTSize);
    w4.rect(posx+1, posy+1, halfTSize, thirdSize);

    w4.rect(posx+1, endposy + thirdSize - 2, thirdSize, halfTSize);
    w4.rect(posx+1, endposy - 1, thirdSize/2, thirdSize);

    w4.rect(endposx-1, posy + 1, thirdSize, halfTSize);
    w4.rect(endposx + thirdSize - 2, posy + 1, halfTSize, thirdSize);

    w4.rect(endposx-1, endposy + thirdSize - 2, thirdSize, halfTSize);
    w4.rect(endposx + thirdSize - 2, endposy-1, halfTSize, thirdSize);
}

fn drawTiles() void {
    const cam = globalBoard.camera;
    const offx = cam.offx;
    const offy = cam.offy;

    var iter = globalBoard.tileIter();

    while (iter.next()) |triple| {
        w4.DRAW_COLORS.* = triple.tile;
        const x = tilesize * (@as(i32, triple.x) - @as(i32, offx));
        const y = tilesize * (@as(i32, triple.y) - @as(i32, offy));
        w4.rect(x, y, tilesize, tilesize);
    }
}

const ST = ?*@import("std").builtin.StackTrace;
pub fn panic(msg: []const u8, trace: ST) noreturn {
    @setCold(true);

    w4.trace(">> ahh, panic!");
    w4.trace(msg);
    if ( trace ) |t| {
        w4.tracef("  index: %d", @intCast(i32, t.index));
    } else {
        w4.trace("  no trace :(");
    }

    while ( true ) {
        @breakpoint();
    }
}
