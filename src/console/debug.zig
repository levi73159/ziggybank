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
    debug_color: ColorSet = .{ .fore = .gray },
    info_color: ColorSet = .{ .fore = .cyan },
    success_color: ColorSet = .{ .fore = .green },
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

const LogLevel = enum {
    print,
    debug,
    // success, // not used, success is info but diffrent color
    info,
    warn,
    err,
    fatal,
};

pub const Logger = struct {
    current_scheme: ColorScheme,

    pub fn init(schme: ColorScheme) Logger {
        return .{
            .current_scheme = schme
        };
    }

    fn printOut(comptime msg: []const u8, args: anytype) void {
        std.io.getStdOut().writer().print(msg, args) catch return;
    }

    fn printErr(comptime msg: []const u8, args: anytype) void {
        std.io.getStdErr().writer().print(msg, args) catch return;
    }

    inline fn getPrefix(comptime level: LogLevel) []const u8 {
        if (level == .print)
            return "";
        return @tagName(level) ++ ": ";
    }

    inline fn getSuffix(comptime level: LogLevel) []const u8 {
        if (level == .print)
            return "";
        return "\n";
    }

    const log_function = fn (comptime msg: []const u8, args: anytype) void;
    inline fn logWrapper(comptime level: LogLevel, color: ColorSet, comptime log: log_function, comptime msg: []const u8, args: anytype) void {
        color.setColor();
        log(getPrefix(level) ++ msg ++ getSuffix(level), args);
        ansi.style.deafultForeColor();
        ansi.style.deafultBackColor();
    }

    pub fn print(self: Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(.print, self.current_scheme.print_color, printOut, msg, args);
    }

    pub fn info(self: Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(.info, self.current_scheme.info_color, printOut, msg, args);
    }   

    pub fn success(self: Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(.info, self.current_scheme.success_color, printOut, msg, args);
    }

    pub fn debug(self: Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(.debug, self.current_scheme.debug_color, printErr, msg, args);
    }

    pub fn warn(self: Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(.warn, self.current_scheme.warn_color, printErr, msg, args);
    }

    pub fn err(self: Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(.err, self.current_scheme.err_color, printErr, msg, args);
    }
    
    pub fn fatal(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        logWrapper(.fatal, self.current_scheme.fatal_color, printErr, msg, args);
    }
};
/// The default Logger
pub const logger = Logger.init(ColorScheme.get_default());