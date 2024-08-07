const std = @import("std");

pub const ansi = @import("ansi/ansi.zig");


pub const CursorMode = enum(u8) {
    blinking_block = 1,
    block,
    blinking_underscore,
    underscore,
    blinking_I_beam,
    I_beam,
};

pub fn bell() void {
    std.debug.print("\x07", .{});
}

pub fn clearCurrentLine() void {
    std.debug.print(ansi.csi ++ "2K", .{});
}

pub fn clearFromCursorToLineBeginning() void {
    std.debug.print(ansi.csi ++ "1K", .{});
}

pub fn clearFromCursorToLineEnd() void {
    std.debug.print(ansi.csi ++ "K", .{});
}

pub fn clearScreen() void {
    std.debug.print(ansi.csi ++ "2J", .{});
}

pub fn clearFromCursorToScreenBeginning() void {
    std.debug.print(ansi.csi ++ "1J", .{});
}

pub fn clearFromCursorToScreenEnd() void {
    std.debug.print(ansi.csi ++ "J", .{});
}



pub fn readlineAlloc(allocator: std.mem.Allocator, askstr: ?[]u8, max_size: usize) ![]u8 {
    const in = std.io.getStdIn().reader();

    if (askstr != null) std.debug.print("{s}", .{askstr.?});

    const result = try in.readUntilDelimiterAlloc(allocator, '\n', max_size);
    return if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;
}