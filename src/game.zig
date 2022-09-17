const w4 = @import("wasm4.zig");

const main = @import("main.zig");

const Input = main.Input;
const State = main.State;
const Board = main.Board;

const tilesize = main.tilesize;

pub fn update(ptrs: State, input: Input) State {
    _ = input;
    return ptrs;
}

pub fn draw(ptrs: State) void {
    drawTiles(ptrs.board.*);
    drawCursor(ptrs.board.*);
}

fn drawCursor(board: Board) void {
    const cursor = board.cursor;
    const camera = board.camera;
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

fn drawTiles(board: Board) void {
    const cam = board.camera;
    const offx = cam.offx;
    const offy = cam.offy;

    var iter = board.tileIter();

    while (iter.next()) |triple| {
        w4.DRAW_COLORS.* = triple.tile;
        const x = tilesize * (@as(i32, triple.x) - @as(i32, offx));
        const y = tilesize * (@as(i32, triple.y) - @as(i32, offy));
        w4.rect(x, y, tilesize, tilesize);
    }
}
