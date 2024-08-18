const std = @import("std");
const debug = @import("debug.zig");

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
    debug.logger.print("\x07", .{});
}

pub fn clearCurrentLine() void {
    debug.logger.print(ansi.csi ++ "2K", .{});
}

pub fn clearFromCursorToLineBeginning() void {
    debug.logger.print(ansi.csi ++ "1K", .{});
}

pub fn clearFromCursorToLineEnd() void {
    debug.logger.print(ansi.csi ++ "K", .{});
}

pub fn clearScreen() void {
    debug.logger.print(ansi.csi ++ "2J", .{});
}

pub fn clearFromCursorToScreenBeginning() void {
    debug.logger.print(ansi.csi ++ "1J", .{});
}

pub fn clearFromCursorToScreenEnd() void {
    debug.logger.print(ansi.csi ++ "J", .{});
}

pub fn clear() void {
    clearFromCursorToScreenBeginning();
    ansi.cursor.setCursorPos(0, 0); // set cursor to top left
}

pub fn pause() void {
    debug.logger.print("Press any key to continue...", .{});
    _ = std.io.getStdIn().reader().readByte() catch return;
}

pub fn readLineAlloc(allocator: std.mem.Allocator, askstr: ?[]const u8, hide_input: bool, max_size: usize) ![]u8 {
    const in = std.io.getStdIn().reader();

    if (askstr != null) debug.logger.print("{s}", .{askstr.?});
    if (hide_input) ansi.style.setStyle(.hide);

    const result = try in.readUntilDelimiterAlloc(allocator, '\n', max_size);
    
    if (hide_input) ansi.style.removeStyle(.hide);
    return if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;
}


pub const name_flag = 0b001;
pub const value_flag = 0b010;
pub const index_flag = 0b100;
/// for the flag option it will choose how they get selected
/// if none is selected it will use all by default, and if all is selected it will also use all
/// 
/// the first bit `0b001` means it will go by name
/// 
/// the second bit `0b010` means it will go by value
/// 
/// the thired bit `0b100` means it will go by index
pub fn getOption(prompt: []const u8, comptime options: type, comptime flag: u3) !options {
    if (@typeInfo(options) != .Enum) @compileError("Must be an enum type!");
    
    const in = std.io.getStdIn().reader();
    // const out = std.io.getStdOut().writer();

    const use_name: bool =  (flag & 0b001) != 0;
    const use_value: bool = (flag & 0b010) != 0;
    const use_index: bool = (flag & 0b100) != 0;

    comptime var max_size: usize = 0;
    ansi.style.setStyle(.italic);
    inline for (@typeInfo(options).Enum.fields, 0..) |option, index| {
        // try out.writeSeq(.{ "  - ", option.name, "\n" });
        if (use_index) debug.logger.print("{} - ", .{index});
        debug.logger.print("{s}", .{option.name});
        if (use_value) debug.logger.print("({})", .{option.value});
        debug.logger.print("\n", .{});
        if (option.name.len > max_size) max_size = option.name.len;
    }
    if (!use_name) max_size = 50;
    ansi.style.removeStyle(.italic);

    while (true) {
        var buffer: [max_size + 1]u8 = undefined;

        // try out.writeSeq(.{ Fg.DarkGray, "\n>", " " });
        ansi.style.setForeColor(.black);
        ansi.style.printStyle("{s}: ", .bold, .{prompt});

        var result = (in.readUntilDelimiterOrEof(&buffer, '\n') catch {
            try in.skipUntilDelimiterOrEof('\n');
            // try out.writeSeq(.{ Fg.Red, "Error: Invalid option, please try again.\n" });
            debug.logger.err("Invalid option, please try again.\n", .{});
            continue;
        }) orelse return error.EndOfStream;
        result = if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;
        const resultInt: ?u32 = std.fmt.parseInt(u32, result, 10) catch null;

        inline for (@typeInfo(options).Enum.fields, 0..) |option, index| {
            if ((use_name and std.mem.eql(u8, option.name, result)) or
            (use_value and resultInt != null and option.value == resultInt.?) or
            (use_index and resultInt != null and index == resultInt.?)) {
                return @enumFromInt(option.value);
            }   
            // return option.value;
        }
        // try out.writeSeq(.{ Fg.Red, "Error: Invalid option, please try again.\n" });
        debug.logger.err("Invalid option, please try again.\n", .{});
    }

    // return undefined;
}

pub fn getBool(prompt: []const u8, default: bool) !bool {
    const in = std.io.getStdIn().reader();
    
    debug.logger.print("{s} ", .{prompt});
    if (default) {
        debug.logger.print("[Y/n] ", .{});
    } else {
        debug.logger.print("[y/N] ", .{});
    }

    while (true) {
        var buffer: [10]u8 = undefined;
        const result = in.readUntilDelimiterOrEof(&buffer, '\n') catch |err| switch (err) {
            error.StreamTooLong => {
                try in.skipUntilDelimiterOrEof('\n');

                debug.logger.err("Steam Too Long, please try again.\n", .{});
                continue;
            },
            else => {
                try in.skipUntilDelimiterOrEof('\n');

                debug.logger.err("Unknow Error: {any}, try again.\n",.{err});
                continue;
            }
        };

        if (result) |r| {
            if (r.len == 0) { return default; }
            else if (std.ascii.toLower(r[0]) == 'y') { return true; }
            else if (std.ascii.toLower(r[0]) == 'n') { return false; }
            else { return false; }
        } else {
            return default;
        }
    }
}