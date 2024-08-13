const std = @import("std");
const ansi = @import("ansi/ansi.zig");

const Color = ansi.style.Color;
pub const ColorSet = struct {
    fore: Color = .default,
    back: Color = .default,

    fn setColor(self: ColorSet) void {
        ansi.style.setForeBack(self.fore, self.back);
    }
};

pub const ColorScheme = struct {
    const default_scheme: ColorScheme = .{};

    print_color: ColorSet = .{ .fore = .white },
    debug_color: ColorSet = .{ .fore = .green },
    info_color: ColorSet = .{ .fore = .cyan },
    warn_color: ColorSet = .{ .fore = .bright_yellow },
    err_color: ColorSet = .{ .fore = .red },
    fatal_color: ColorSet = .{ .fore = .bright_white, .back = .red },

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

    const log_function = fn (comptime msg: []const u8, args: anytype) void;
    inline fn logWrapper(color: ColorSet, log: log_function, comptime msg: []const u8, args: anytype) void {
        color.setColor();
        log(msg, args);
        ansi.style.deafultForeColor();
        ansi.style.deafultBackColor();
    }

    pub fn print(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(self.current_scheme.print_color, std.debug.print, msg, args);
    }

    pub fn debug(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(self.current_scheme.debug_color, std.log.debug, msg, args);
    }

    pub fn info(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(self.current_scheme.info_color, std.log.info, msg, args);
    }   

    pub fn warn(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(self.current_scheme.warn_color, std.log.warn, msg, args);
    }

    pub fn err(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(self.current_scheme.err_color, std.log.err, msg, args);
    }
    
    pub fn fatal(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(self.current_scheme.fatal_color, std.log.err, msg, args);
    }
};
/// The default Logger
pub const logger = Logger.init(ColorScheme.get_default());