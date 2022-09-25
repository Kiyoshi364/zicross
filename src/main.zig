const w4 = @import("wasm4.zig");

const pg = @import("pure_garbage.zig");
const game = @import("game.zig");

const Input = game.Input;
const State = game.State;
const Board = game.Board;

const mem_size = 58976;
const mem_ptr = @intToPtr(*anyopaque, 0x19a0);
const mem_buf = @ptrCast(*[mem_size]u8, mem_ptr);

const state_ptr = @ptrCast(*State, mem_ptr);

export fn start() void {
    const debug = @import("builtin").mode == .Debug;
    if ( debug ) {
        w4.tone(262 | (253 << 16), 60, 30, w4.TONE_PULSE1 | w4.TONE_MODE3);
    }

    state_ptr.* = game.firstState();
}

export fn update() void {
    const input = game.sampleInput();

    state_ptr.* = game.update(state_ptr.*, input);
    game.draw(state_ptr.*);
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
