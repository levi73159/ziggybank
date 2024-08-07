const std = @import("std");

const csi = "\x1B[";

fn selectGraphicRendition(n: u32) void {
    std.debug.print(csi ++ "{}m", .{n});
}

fn selectGraphicRenditionArg1(n: u32, arg1: u32) void {
    std.debug.print(csi ++ "{};{}m", .{n, arg1});
}

fn selectGraphicRenditionArg2(n: u32, arg1: u32, arg2: u32) void {
    std.debug.print(csi ++ "{};{};{}m", .{n, arg1, arg2});
}

fn selectGraphicRenditionArg3(n: u32, arg1: u32, arg2: u32, arg3: u32) void {
    std.debug.print(csi ++ "{};{};{};{}m", .{n, arg1, arg2, arg3});
}

fn selectGraphicRenditionArg4(n: u32, arg1: u32, arg2: u32, arg3: u32, arg4: u32) void {
    std.debug.print(csi ++ "{};{};{};{};{}m", .{n, arg1, arg2, arg3, arg4});
}

pub fn default() void { selectGraphicRendition(0); }

pub const Style = enum(u32) {
    bold = 1,
    faint,
    italic, underline,
    slow_blink, rapid_blink,
    invert,
    hide, strike,
    double_underline = 21,

    framed=51, encircled,
    overlined,

    // super script and sub script and no script is no special script evect
    superscript = 73,
    subscript,
};
pub fn setStyles(styles: []Style) void {
    for (styles) |style| {
        setStyle(style);
    }
}

pub fn setStyle(style: Style) void {
    selectGraphicRendition(@intFromEnum(style));
}

pub fn removeStyle(style: Style) void {
    switch (style) {
        .bold, .faint => selectGraphicRendition(22),
        .rapid_blink, .slow_blink => selectGraphicRendition(25),
        .framed, .encircled => selectGraphicRendition(54),
        .overlined => selectGraphicRendition(55),
        .superscript, .subscript => selectGraphicRendition(75),
        .double_underline => selectGraphicRendition(24),
        else => selectGraphicRendition(@intFromEnum(style)+20)
    }
}

pub fn removeStyles(styles: []Style) void {
    for (styles) |style| {
        removeStyle(style);
    }
}

pub fn printStyles(comptime format: []const u8, styles: []Style, args: anytype) void {
    setStyles(styles);
    std.debug.print(format, args);
    removeStyles(styles);
}

pub fn printStyle(comptime format: []const u8, style: Style, args: anytype) void {
    setStyle(style);
    std.debug.print(format, args);
    removeStyle(style);
}

const FontError = error {
    InvalidFontIndex
};

/// Font 10 (Fraktur Gothic) is rarely supported.
/// font index must be through 0-10 otherwise `error.InvalidFontIndex`
pub fn setFont(font: u4) FontError!void {
    if (font > 10)
        return error.InvalidFontIndex;
    selectGraphicRendition(10 + @as(u32, font));
}


pub const Color = enum(u32) {
    black = 30, red, green, yellow, blue, magenta, cyan, white,
    gray = 90, bright_red, bright_green, bright_yellow, bright_blue, bright_magenta, bright_cyan, bright_white
};

pub fn setForeColor(color: Color) void { selectGraphicRendition(@intFromEnum(color)); }
pub fn setBackColor(color: Color) void { selectGraphicRendition(@intFromEnum(color)+10); }
pub fn setForeBack(fore: Color, back: Color) void {
    setForeColor(fore);
    setBackColor(back);
}

/// becarefull for integer overflow
pub inline fn get8BitColor(r: u8, g: u8, b: u8) u8 { return 16 + 36 * r + 6 * g + b; }
pub inline fn getBrightness(brightness: u8) u8 { return brightness + 232; }

pub fn setFore8bColor(color: u8) void {
    selectGraphicRenditionArg2(38, 5, @intCast(color));
}

pub fn setBack8bColor(color: u8) void {
    selectGraphicRenditionArg2(48, 5, @intCast(color));
}

pub fn setForeRGB(r: u8, g: u8, b: u8) void {
    selectGraphicRenditionArg4(38, 2, @intCast(r), @intCast(g), @intCast(b));
}

pub fn setBackRGB(r: u8, g: u8, b: u8) void {
    selectGraphicRenditionArg4(48, 2, @intCast(r), @intCast(g), @intCast(b));
}

pub fn deafultForeColor() void {
    selectGraphicRendition(39);
}

pub fn deafultBackColor() void {
    selectGraphicRendition(49);
}