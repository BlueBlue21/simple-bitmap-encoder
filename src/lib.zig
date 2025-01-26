const std = @import("std");

const testingAllocator = std.testing.allocator;
const expect = std.testing.expect;

const Allocator = std.mem.Allocator;
const File = std.fs.File;
const ColorT = usize;

pub const Bitmap = struct {
    allocator: Allocator,
    width: i32,
    height: i32,
    pixels: []ColorT,

    const Self = @This();

    pub fn init(allocator: Allocator, width: i32, height: i32) !Self {
        const pixels = try allocator.alloc(
            ColorT,
            @as(ColorT, @intCast(width * height * @sizeOf(ColorT))),
        );

        for (0..pixels.len) |index| {
            pixels[index] = 0;
        }

        return Self{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    pub fn setPixel(self: *Self, x: i32, y: i32, color: ColorT) void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return;
        }

        self.pixels[@as(ColorT, @intCast(y * self.width + x))] = color;
    }

    pub fn fill(self: *Self, x1: i32, y1: i32, x2: i32, y2: i32, color: ColorT) void {
        var y = y1;
        while (y <= y2) : (y += 1) {
            var x = x1;
            while (x <= x2) : (x += 1) {
                self.setPixel(x, y, color);
            }
        }
    }

    fn calcRowSize(width: i32) i32 {
        var rowLength: i32 = width * 3;
        rowLength += 4 - @rem(rowLength, 4);
        std.debug.assert(@rem(rowLength, 4) == 0);

        return rowLength;
    }

    fn calcImageSize(width: i32, height: i32) i32 {
        return calcRowSize(width) * height;
    }

    fn writeFileHeader(width: i32, height: i32, file: File) !void {
        const fileWriter = file.writer();

        const magicWord = [2]u8{ 'B', 'M' };
        try fileWriter.writeAll(&magicWord);

        const fileSize: i32 = 14 + 40 + calcImageSize(width, height);
        const reversed: i32 = 0;
        const offset: i32 = 14 + 40;

        const fileHeader = [3]i32{ fileSize, reversed, offset };

        for (fileHeader) |value| {
            try fileWriter.writeInt(i32, value, .little);
        }
    }

    fn writeInfoHeader(width: i32, height: i32, file: File) !void {
        const fileWriter = file.writer();

        const headerSize: i32 = 40;
        const planes: i32 = 1;
        const bitsPerPixel: i32 = 24;
        const compression: i32 = 0;
        const imageSize = calcImageSize(width, height);
        const xPixelsPerMeter: i32 = 0;
        const yPixelsPerMeter: i32 = 0;
        const colorsUsed: i32 = 0;
        const importantColorsUsed: i32 = 0;

        const infoHeader = [11][2]i32{
            .{ 4, headerSize },
            .{ 4, width },
            .{ 4, height },
            .{ 2, planes },
            .{ 2, bitsPerPixel },
            .{ 4, compression },
            .{ 4, imageSize },
            .{ 4, xPixelsPerMeter },
            .{ 4, yPixelsPerMeter },
            .{ 4, colorsUsed },
            .{ 4, importantColorsUsed },
        };
        for (infoHeader) |value| {
            if (value[0] == 4) {
                try fileWriter.writeInt(i32, value[1], .little);
            } else if (value[0] == 2) {
                try fileWriter.writeInt(i16, @intCast(value[1]), .little);
            }
        }
    }

    fn writePixelData(self: *Self, file: File) !void {
        const fileWriter = file.writer();

        const width = self.width;
        const rowSize = calcRowSize(width);

        var y: i32 = self.height - 1;
        while (y >= 0) : (y -= 1) {
            var x: i32 = 0;
            while (x < width) : (x += 1) {
                const color: ColorT = self.pixels[@as(ColorT, @intCast(y * width + x))];
                const red = (color & 0xFF0000) >> 16;
                const green = (color & 0x00FF00) >> 8;
                const blue = color & 0x0000FF;

                const rgb = [3]ColorT{ blue, green, red };
                for (rgb) |value| {
                    try fileWriter.writeInt(u8, @intCast(value), .little);
                }
            }

            var i: i32 = width * 3;
            while (i < rowSize) : (i += 1) {
                try fileWriter.writeByte(0);
            }
        }
    }

    pub fn writeBitmap(self: *Self, filename: []const u8) !void {
        const allocator = self.allocator;
        const filenameWithExtension = try std.fmt.allocPrint(
            allocator,
            "{s}.bmp",
            .{filename},
        );
        defer allocator.free(filenameWithExtension);

        const file = try std.fs.cwd().createFile(
            filenameWithExtension,
            .{ .read = true },
        );
        defer file.close();

        const width = self.width;
        const height = self.height;

        try writeFileHeader(width, height, file);
        try writeInfoHeader(width, height, file);
        try writePixelData(self, file);
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.pixels);
        self.* = undefined;
    }
};

test "test init" {
    var bitmap = try Bitmap.init(testingAllocator, 10, 10);
    defer bitmap.deinit();

    try expect(bitmap.width == 10 and bitmap.height == 10);
}

test "test set pixel" {
    var bitmap = try Bitmap.init(testingAllocator, 10, 10);
    defer bitmap.deinit();

    bitmap.setPixel(0, 0, 0xFFFFFF);

    try expect(bitmap.pixels[0] == 16777215);
}
