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

    const test_step = b.step("test", "Run all tests");
    try testFilesFromDir(b, test_step, "src",
        &[_][]const u8{
            "main.zig",
            "wasm4.zig",
        });
}

fn testFilesFromDir(
        b: *std.build.Builder,
        test_step: *std.build.Step,
        dirpath: []const u8,
        ignores: []const []const u8
) !void {
    const cwd = std.fs.cwd();
    const itdir = try cwd.openIterableDir(dirpath, .{});
    var iter = itdir.iterate();
    while ( try iter.next() ) |entry| {
        switch ( entry.kind ) {
            .File => blk: {
                for ( ignores ) |ig| {
                    if ( std.mem.eql(u8, ig, entry.name) ) break :blk;
                }
                const filename
                    = try itdir.dir.realpathAlloc(b.allocator,
                        entry.name);
                defer b.allocator.free(filename);
                test_step.dependOn(&b.addTest(filename).step);
            },
            else => {},
        }
    }
}
