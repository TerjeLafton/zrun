const std = @import("std");

const Launcher = @import("Launcher.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var launcher = Launcher.init(arena.allocator());
    try launcher.run();
}
