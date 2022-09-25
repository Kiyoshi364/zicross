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

const Board = boardLib.Board(Tile, boardWidth, boardHeight);
const Camera = boardLib.Camera(cam_opts, boardWidth, boardHeight);
const Cursor = boardLib.Cursor(cur_opts, boardWidth, boardHeight);

const gpads_max_timer = 10;

pub const State = struct {
    gpads: [4]u8 = .{ 0 } ** 4,
    timer: [4]u4 = .{ 0 } ** 4,

    board: Board = .{},
    camera: Camera = .{},
    cursor: Cursor = .{},
};

pub const Input = struct {
    gpads: [4]u8,
};

pub fn firstState() State {
    var board = Board{};
    { // Init board
        var iter = board.tileIterRef();
        while (iter.next()) |triple| {
            const x = triple.x;
            const y = triple.y;
            triple.tile.* = @intCast(Tile, (x+y)%3 + 1);
        }
    }

    const state = State{
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
    var newstate = oldstate;

    { // Reading inputs
        const bstats
            = boardLib.checkInput(oldstate.gpads[0], input.gpads[0]);
        const moveUp
            = oldstate.cursor.y > 0
            and ( bstats[0] == .Pressed
                or (bstats[0] == .Held and oldstate.timer[0] == 0) );
        const moveDown
            = oldstate.cursor.y < @TypeOf(oldstate.board).height - 1
            and ( bstats[2] == .Pressed
                or (bstats[2] == .Held and oldstate.timer[2] == 0) );
        const moveLeft
            = oldstate.cursor.x > 0
            and ( bstats[1] == .Pressed
                or (bstats[1] == .Held and oldstate.timer[1] == 0) );
        const moveRight
            = oldstate.cursor.x < @TypeOf(oldstate.board).width - 1
            and ( bstats[3] == .Pressed
                or (bstats[3] == .Held and oldstate.timer[3] == 0) );
        const button1 = bstats[4];
        const button2 = bstats[5];

        if ( moveUp ) {
            newstate.timer[0] = gpads_max_timer;
            newstate.cursor.y -= 1;
        } else if ( moveDown ) {
            newstate.timer[2] = gpads_max_timer;
            newstate.cursor.y += 1;
        }

        if ( moveLeft ) {
            newstate.timer[1] = gpads_max_timer;
            newstate.cursor.x -= 1;
        } else if ( moveRight ) {
            newstate.timer[3] = gpads_max_timer;
            newstate.cursor.x += 1;
        }

        switch ( button1 ) {
            .Released => {},
            .Pressed => {},
            .Unpressed => {},
            .Held => {},
        }

        switch ( button2 ) {
            .Released => {},
            .Pressed => {},
            .Unpressed => {},
            .Held => {},
        }

        for (newstate.timer) |*t| if ( t.* > 0 ) { t.* -= 1; };
    }

    newstate.gpads = input.gpads;
    return newstate;
}

pub fn draw(state: State) void {
    drawTiles(state.board, state.camera);
    drawCursor(state.camera, state.cursor);
    drawInputs(state.gpads[0]);
}

fn drawCursor(camera: Camera, cursor: Cursor) void {
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

fn drawTiles(board: Board, cam: Camera) void {
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

fn drawInputs(pad: u8) void {
    const initx = 2;
    const scalex = 8;
    const y = 2;
    const chars = " \x80\x81\x82\x83\x84\x85\x86\x87";
    var i = @as(u4, 0);
    while ( i < 8 ) : ( i += 1 ) {
        const mask = (pad >> @intCast(u3, i)) & 1;
        const key = mask * (i + 1);
        w4.text(chars[key..key+1], initx + scalex * @as(i32, i), y);
    }
}
