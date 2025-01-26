const std = @import("std");
const lib = @import("lib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();
    var bitmap = try lib.Bitmap.init(allocator, 10, 10);
    defer bitmap.deinit();

    // ._.
    bitmap.setPixel(2, 2, 0xFFFFFF);
    bitmap.setPixel(7, 2, 0xFFFFFF);
    bitmap.fill(3, 7, 6, 7, 0xFFFFFF);

    try bitmap.writeBitmap("dot");
}
