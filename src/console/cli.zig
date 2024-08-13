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


pub fn readLineAlloc(allocator: std.mem.Allocator, askstr: ?[]const u8, hide_input: bool, max_size: usize) ![]u8 {
    const in = std.io.getStdIn().reader();

    if (askstr != null) std.debug.print("{s}", .{askstr.?});
    if (hide_input) ansi.style.setStyle(.hide);

    const result = try in.readUntilDelimiterAlloc(allocator, '\n', max_size);
    
    if (hide_input) ansi.style.removeStyle(.hide);
    return if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;
}


/// for the flag option it will choose how they get selected
/// if none is selected it will use all by default, and if all is selected it will also use all
/// 
/// the first bit `0b001` means it will go by name
/// 
/// the second bit `0b010` means it will go by value
/// 
/// the thired bit `0b100` means it will go by index
pub fn getOption(prompt: []const u8, comptime options: type, comptime flag: u3) !options {
    if (@typeInfo(options).Type != .Enum) @compileError("Must be an enum type!");
    
    const in = std.io.getStdIn().reader();

    const use_name: bool =  (flag & 0b001) != 0;
    const use_value: bool = (flag & 0b010) != 0;
    const use_index: bool = (flag & 0b100) != 0;

    comptime var max_size: usize = 0;
    ansi.style.setStyle(.italic);
    inline for (@typeInfo(options).Enum.fields, 0..) |option, index| {
        // try out.writeSeq(.{ "  - ", option.name, "\n" });
        if (use_index) std.debug.print("{} - ", .{index});
        std.debug.print("{s}", .{option.name});
        if (use_value) std.debug.print("({})", .{option.value});
        std.debug.print("\n", .{});
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
            ansi.style.printColor("Error: Invalid option, please try again.\n", .red, .default, .{});
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
        ansi.style.printColor("Error: Invalid option, please try again.\n", .red, .default, .{});
    }

    // return undefined;
}