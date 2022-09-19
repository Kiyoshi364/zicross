const w4 = @import("wasm4.zig");

const boardLib = @import("board.zig");

const SCREEN_WIDTH = 160;
const SCREEN_HEIGHT = 160;

const tilesize = 9;

pub const Tile = u2;
pub const boardWidth = 32;
pub const boardHeight = boardWidth;

const cam_opts = boardLib.CameraOptions{
    .screen_width = 160 / tilesize,
    .screen_height = 160 / tilesize,
};
const cur_opts = boardLib.CursorOptions{
    .init_x = 5,
    .init_y = 7,
};

pub const Board = boardLib.Board(void, Tile, boardWidth, boardHeight, .{
    .use_camera = cam_opts,
    .use_cursor = cur_opts,
});

pub const State = struct {
    old_gpads: [4]u8,
    board: Board,
};

pub const Input = struct {
    gpads: [4]u8,
};

pub fn firstState() State {
    var board = Board{
        .data = {},
        .tiles = [_][boardHeight]Tile{ [_]Tile{ 0 } ** boardHeight } ** boardWidth,
    };

    {
        var iter = board.tileIterRef();
        while (iter.next()) |triple| {
            const x = triple.x;
            const y = triple.y;
            triple.tile.* = @intCast(Tile, (x+y)%3 + 1);
        }
    }

    const state = State{
        .old_gpads = [_]u8{ 0 } ** 4,
        .board = board,
    };
    return state;
}

pub fn sampleInput() Input {
    const input = Input{
        .gpads = @as(*const [4]u8, w4.GAMEPAD1).*,
    };
    return input;
}

pub fn update(oldstate: State, input: Input) State {
    _ = input;
    return oldstate;
}

pub fn draw(state: State) void {
    drawTiles(state.board);
    drawCursor(state.board);
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
