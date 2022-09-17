const w4 = @import("wasm4.zig");

const board = @import("board.zig");
const game = @import("game.zig");

const SCREEN_WIDTH = 160;
const SCREEN_HEIGHT = 160;

pub const tilesize = 9;

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

pub const Board = board.Board(void, Tile, boardWidth, boardHeight, .{
    .use_camera = cam_opts,
    .use_cursor = cur_opts,
});

pub const State = struct {
    board: *Board,

    const Self = @This();

    pub const MAXSIZE = 58975;
    const mem_ptr = 0x19a0;
    const mem_buf = @intToPtr(*[MAXSIZE]u8, mem_ptr);

    pub const alloced_memory = calc_used();

    fn init() Self {
        comptime var self: Self = undefined;
        comptime var alloc = 0;

        inline for (@typeInfo(Self).Struct.fields) |field| {
            const T = @typeInfo(field.field_type).Pointer.child;
            switch (@typeInfo(T)) {
                .Int, .Bool, .Array, .Struct, .Enum => {
                    const size = @sizeOf(T);
                    if ( alloc + size > MAXSIZE ) {
                        @compileLog("Type to alloc", T);
                        @compileLog("Size to alloc", size);
                        @compileLog("Before alloc", alloc);
                        @compileLog("After alloc", alloc + size);
                        @compileError("ptrs.init: Not enough memory!");
                    }
                    @field(self, field.name) = @intToPtr(*T, mem_ptr + alloc);
                    alloc += size;
                },
                else => {
                    @compileLog(field.name, T);
                    @compileError("ptrs: unhandled case.\nIf you got this compileError, consider adding a case for the unhandled type.");
                },
            }
        }
        return self;
    }

    fn calc_used() comptime_int {
        comptime var alloc = 0;
        inline for (@typeInfo(Self).Struct.fields) |field| {
            const T = @typeInfo(field.field_type).Pointer.child;
            const size = @sizeOf(T);
            alloc += size;
        }
        return alloc;
    }
};

const ptrs: State = State.init();

pub const Input = void;

export fn start() void {
    const debug = @import("builtin").mode == .Debug;
    if ( debug ) {
        w4.tone(262 | (253 << 16), 60, 30, w4.TONE_PULSE1 | w4.TONE_MODE3);
    }
    ptrs.board.* = Board{
        .data = {},
        .tiles = [_][boardHeight]Tile{ [_]Tile{ 0 } ** boardHeight } ** boardWidth,
    };

    {
        var iter = ptrs.board.tileIterRef();
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

    const pad_old = w4.GAMEPAD1.*;
    const pad_new = w4.GAMEPAD1.*;
    const pad_diff = pad_old ^ pad_new;
    _ = pad_diff;

    if (pad_new & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 4;
    }

    const input = Input{};

    _ = game.update(ptrs, input);
    game.draw(ptrs);
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
