const std = @import("std");
const account = @import("account.zig");
const UUID = @import("UUID.zig").UUID;
const cli = @import("console/cli.zig");

// fn createAccountCLI() void {
//     cli.ansi.style.printStyle("create Account! BOLD\n", .bold, .{});
//     cli.ansi.style.printStyle("create Account! FAINT\n", .faint, .{});
//     cli.ansi.style.printStyle("create Account! ITALIC\n", .italic, .{});
//     cli.ansi.style.printStyle("create Account! underline\n", .underline, .{});
//     cli.ansi.style.printStyle("create Account! slow_blink\n", .slow_blink, .{});
//     cli.ansi.style.printStyle("create Account! rapid_blink\n", .rapid_blink, .{});
//     cli.ansi.style.printStyle("create Account! invert\n", .invert, .{});
//     cli.ansi.style.printStyle("create Account! HIDE\n", .hide, .{});
//     cli.ansi.style.printStyle("create Account! strike\n", .strike, .{});
//     cli.ansi.style.printStyle("create Account! double_underline\n", .double_underline, .{});
//     cli.ansi.style.printStyle("create Account! framed\n", .framed, .{});
//     cli.ansi.style.printStyle("create Account! encircled\n", .encircled, .{});
//     cli.ansi.style.printStyle("create Account! overlined\n", .overlined, .{});
//     cli.ansi.style.printStyle("create Account! superscript", .superscript, .{});
//     cli.ansi.style.printStyle("create Account! subscript\n", .subscript, .{});
// }

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        std.debug.print("Usage: {s} <command> <account>\n", .{args[0]});
        return;
    }

    const command_name = args[1];
    const user_name = args[2];

    const bank_cache_path = ".bank-cache";
    var bank_directory = std.fs.cwd().openDir(bank_cache_path, .{}) catch |e| switch (e) {
        error.FileNotFound => make: {
            try std.fs.cwd().makeDir(bank_cache_path);
            break :make try std.fs.cwd().openDir(bank_cache_path, .{});
        },
        else => return e
    };
    defer bank_directory.close();

    const bankdata_filename = "banking.dat";
    const bankdata_file = bank_directory.openFile(bankdata_filename, .{.mode = .read_write}) catch |e| switch (e) {
        error.FileNotFound => try bank_directory.createFile(bankdata_filename, .{.read=true, .mode=0o666}),
        else => return e
    };
    defer bankdata_file.close();

    // var int_bytes = [4]u8{0,0,0,0};
    // std.mem.writeInt(u32, &int_bytes, 3251, .big);
    // std.debug.print("{any}\n", .{int_bytes});

    const accounts = account.AccountInfo.parseFile(bankdata_file) catch |err|{ 
            switch (err) {
                error.FileToBig => std.debug.print("Error: File have reached max capacity!", .{}),
                error.NameTooBig => std.debug.print("Error: Name too big! max name size is {}", .{account.AccountInfo.name_max_length}),
                error.PermisonDenied => std.debug.print("Error: Can't read file, permison denied!", .{}),
                error.Invalid => std.debug.print("Error: Failed to read data due to invalid format!", .{}),
                error.EndOfFile => std.debug.print("Error: Unexpected end of file!", .{}),
                else => unreachable
            }
            return;
    };

    

    if (std.mem.eql(u8, command_name, "create")) {
        for (accounts.items) |a| {
            if (std.mem.eql(u8, a.name, user_name)) {
                std.debug.print("account already exists, do open to open the account\n", .{});
                break;
            }
        } else {
            const accountInfo = account.AccountInfo.create(user_name, UUID.init());
            accountInfo.write(bankdata_file) catch |e| {
                std.debug.print("Error: {} when trying to create the account!\n", .{e});
                return;
            };
            var data = account.AccountData.createEmpty(bank_directory, accountInfo, "this_password_is_test", true) catch |e| {
                std.debug.print("Error: {} when trying to create the account!\n", .{e});
                return;
            };
            defer data.close();
        }
    } else if (std.mem.eql(u8, command_name, "open")) {
        const info = get: {
            for (accounts.items) |a| {
                if (std.mem.eql(u8, a.name, user_name)) break :get a;
            } else {
                std.debug.print("Account does not exists, do create to create a new account\n", .{});
                return;
            }
        };
        // open the account data
        var data = account.AccountData.open(bank_directory, info) catch |e| {
            std.debug.print("Error: {} when trying to open the account data!\n", .{e});
            return;
        };
        defer data.close();

        std.debug.print("Account data:\n", .{});
        std.debug.print("\tName: {s}\n", .{info.name});
        std.debug.print("\tEmail: {s}\n", .{data.email});
        std.debug.print("\tPassword: {any}\n", .{data.password});
        std.debug.print("\tBalance: {d:.2}\n", .{data.balance.*});
    }
}