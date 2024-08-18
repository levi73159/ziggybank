const std = @import("std");
// const debug = @import("../debug.zig");

const csi = "\x1B[";

pub const Position = enum(u8) {
    up = 'A',
    down, foward, backward,
    next_line, prev_line,
    horizotal_absolut,
};

inline fn print(comptime msg: []const u8, args: anytype) void {
    std.io.getStdOut().writer().print(msg, args) catch return;
}

/// Moves the cursor amount cells in the given direction. If the cursor is already at the edge of the screen, this has no effect. 
pub fn moveCursor(amount: u32, pos: Position) void {
    print(csi ++ "{}{c}", .{amount, @intFromEnum(pos)});
}

/// Moves the cursor to the row n column. 
/// The values are 1-based, and default to 1 (top left corner) if omitted.
/// A sequence such as `CSI ;5H` is a synonym for `CSI 1;5H` as well as `CSI 17;H` is the same as `CSI 17H` and `CSI 17;1H`
pub fn setCursorPos(row: u32, colum: u32) void {
    print(csi ++ "{};{}H", .{row, colum});
}

/// lears part of the screen. If n is 0 (or missing), clear from cursor to end of screen. If n is 1, clear from cursor to beginning of the screen.
/// If n is 2, clear entire screen (and moves cursor to upper left on DOS ANSI.SYS).
/// If n is 3, clear entire screen and delete all lines saved in the scrollback buffer (this feature was added for xterm and is supported by other terminal applications). 
pub fn eraseInDisplay(n: u32) void {
    print(csi ++ "{}J", .{n});
}

/// Erases part of the line. If n is 0 (or missing), clear from cursor to the end of the line. 
/// If n is 1, clear from cursor to beginning of the line. If n is 2, clear entire line. Cursor position does not change. 
pub fn eraseInLine(n: u32) void {
    print(csi ++ "{}K", .{n});
}

/// Scroll whole page up by n lines. New lines are added at the bottom. (not ANSI.SYS) 
pub fn scrollUp(n: u32) void { 
    print(csi ++ "{}S", .{n});
}

/// roll whole page down by n lines. New lines are added at the top. (not ANSI.SYS) 
pub fn scrollDown(n: u32) void { 
    print(csi ++ "{}T", .{n});
}

///Same as `setCursorPos`, but counts as a format effector function (like CR or LF) rather than an editor function (like `CUD` or `CNL`). This can lead to different handling in certain terminal modes.
pub fn horizontalVerticalPosition(row: u32, colum: u32) void {
    print(csi ++ "{};{}f", .{row, colum});
}

/// Saves the cursor position/state in SCO console mode.
/// In vertical split screen mode, instead used to set (as CSI n ; n s) or reset left and right margins.
pub fn saveCurrentCursor() void {
    print(csi ++ "s", .{});
}

/// Restores the cursor position/state in SCO console mode
pub fn restoreSavedCursor() void {
    print(csi ++ "u", .{});
}