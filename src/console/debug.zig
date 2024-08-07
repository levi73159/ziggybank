const std = @import("std");
const ansi = @import("ansi/ansi.zig");

const Color = ansi.style.Color;
pub const ColorSet = struct {
    fore: Color,
    back: Color,

    fn setColor(self: ColorSet) void {
        ansi.style.setForeBack(self.fore, self.back);
    }
};

pub const ColorScheme = struct {
    const default_scheme: ColorScheme = .{};

    print_color: ColorSet = .{ .fore = .white, .back = .black  },
    debug_color: ColorSet = .{ .fore = .green, .back = .black },
    info_color: ColorSet = .{ .fore = .cyan, .back = .black },
    warn_color: ColorSet = .{ .fore = .bright_yellow, .back = .gray },
    err_color: ColorSet = .{ .fore = .red, .back = .gray },
    fatal_color: ColorSet = .{ .fore = .bright_red, .back = .bright_white },

    pub fn new(print: ColorSet, debug: ColorSet, info: ColorSet, warn: ColorSet, err: ColorSet, fatal: ColorSet) ColorScheme {
        return ColorScheme{
            .print_color = print,
            .debug_color = debug,
            .info_color = info,
            .warn_color = warn,
            .err_color = err,
            .fatal_color = fatal
        };
    }

    pub inline fn get_default() ColorScheme { return default_scheme; }
};


pub const Logger = struct {
    current_scheme: ColorScheme,

    pub fn init(schme: ColorScheme) Logger {
        return .{
            .current_scheme = schme
        };
    }

    pub fn print(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        self.current_scheme.print_color.setColor();
        std.debug.print(msg, args);
    }

    pub fn debug(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        self.current_scheme.debug_color.setColor();
        std.log.debug(msg, args);
    }

    pub fn info(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        self.current_scheme.info_color.setColor();
        std.log.info(msg, args);
    }   

    pub fn err(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        self.current_scheme.err_color.setColor();
        std.log.err(msg, args);
    }
    
    pub fn fatal(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        self.current_scheme.fatal_color.setColor();
        std.log.err(msg, args);
    }
};
/// The default Logger
pub const logger = Logger.init(ColorScheme.get_default());