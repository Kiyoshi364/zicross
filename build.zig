const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();
    const lib = b.addSharedLibrary("cart", "src/main.zig", .unversioned);

    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;

    // Export WASM-4 symbols
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };

    lib.install();

    // TODO: look for an entire folder
    const files = [_][]const u8{
        "src/utils.zig",
        "src/board.zig",
    };
    const test_step = b.step("test", "Run all tests");
    for (files) |file| {
        test_step.dependOn(&b.addTest(file).step);
    }
}
