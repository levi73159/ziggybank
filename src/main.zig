const std = @import("std");
const account = @import("account.zig");
const UUID = @import("UUID.zig").UUID;
const cli = @import("console/cli.zig");
const debug = @import("console/debug.zig");
const hashEqual = @import("encrypter.zig").hashEqual;

const style = cli.ansi.style;

const allocator = std.heap.page_allocator;

fn createAccountCLI(username: []const u8, file: std.fs.File, directory: std.fs.Dir) !account.AccountData {
    style.setForeColor(.bright_white);
    style.printStyle("Creating an account named {s}!\n", .bold, .{username});
    style.setForeColor(.cyan);
    cli.bell();
    const email = try cli.readLineAlloc(allocator, "(optional) email? ", false, account.AccountInfo.name_max_length);
    const password = try cli.readLineAlloc(allocator, "password? ", true, account.AccountInfo.name_max_length);
    defer allocator.free(email);
    defer allocator.free(password);

    const info = account.AccountInfo.create(username, UUID.init());
    try info.write(file);

    // create copys the strings so we need to free the email n password
    return account.AccountData.create(directory, info, email, password, 0, true);
}

// return false if user not found
fn loginCLI(maybe_username: ?[]const u8, users_lookup: []account.AccountInfo, directory: std.fs.Dir, out_data: *account.AccountData) !bool {
    const username = blk: {
        if (maybe_username) |un| {
            break :blk try allocator.dupe(u8, un);
        } else {
            while(true) {
                const un = cli.readLineAlloc(allocator, "username: ", false, account.AccountInfo.name_max_length) catch continue;
                break :blk un;
            }
        }
    };
    defer allocator.free(username);

    const password = blk: {
        while(true) {
            std.debug.print("password: ", .{});
            const pas = cli.readLineAlloc(allocator, null, true, account.AccountInfo.name_max_length) catch continue;
            break :blk pas;
        }
    };
    defer allocator.free(password);

    // see if the user exists
    out_data.* = blk: for (users_lookup) |user_info| {
        if (std.mem.eql(u8, username, user_info.name)) {
            // get the data
            break :blk try account.AccountData.open(directory, user_info);
        }
    } else return false;

    if (!(hashEqual(allocator, out_data.*.password, password) catch unreachable)) {
        return false; // password not equal
    }

    return true;
}

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        std.debug.print("Usage: {s} <command> <optional account name>\n", .{args[0]});
        std.process.exit(1);
    }
    const command_name: []u8 = args[1];
    const username: ?[]u8 = if (args.len > 2) args[2] else null;

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
            error.FileToBig => debug.logger.err("File have reached max capacity!", .{}),
            error.NameTooBig => debug.logger.err("Name too big! max name size is {}", .{account.AccountInfo.name_max_length}),
            error.PermisonDenied => debug.logger.err("Can't read file, permison denied!", .{}),
            error.Invalid => debug.logger.err("Failed to read data due to invalid format!", .{}),
            error.EndOfFile => debug.logger.err("Unexpected end of file!", .{}),
            else => unreachable
        }
        std.process.exit(1);
    };


    if (std.mem.eql(u8, command_name, "create")) {
        if (username == null) {
            debug.logger.err("Must specify username!", .{});
            debug.logger.info("Usage: {s} create <username>", .{args[0]});
            std.process.exit(1);
        }
        for (accounts.items) |a| {
            if (std.mem.eql(u8, a.name, username.?)) {
                debug.logger.debug("Account already exists, do open to open the account", .{});
                break;
            }
        } else {
            var data = createAccountCLI(username.?, bankdata_file, bank_directory) catch |e| {
                debug.logger.err("{} when trying to open the account data!", .{e});
                return;
            };
            defer data.close();
        }
    } else if (std.mem.eql(u8, command_name, "open")) {
        var userdata: account.AccountData = undefined;
        const success = loginCLI(username, accounts.items, bank_directory, &userdata) catch |err| {
            switch (err) {
                error.AccountFileNotFound => debug.logger.err("Account Not Found!", .{}),
                error.TextTooBig => debug.logger.err("Text Too Big!", .{}),
                error.EndOfFile =>  debug.logger.err("Unexpected End Of File!", .{}),
                error.Undefined => debug.logger.err("Undefined Behiavor!", .{}),
                error.Unexpected => debug.logger.err("Unexpected Error!", .{}),
                else => debug.logger.err("{any}", .{err})
            }
            std.process.exit(1);
        };
        if (success) {
            debug.logger.info("Login success!", .{});
        } else {
            debug.logger.err("Invalid Username or Passsowrd!", .{});
            std.process.exit(1);
        }
    } else if (std.mem.eql(u8, command_name, "delete")) {
        if (username == null) {
            debug.logger.err("Must specify username!", .{});
            debug.logger.info("Usage: {s} delete <username>", .{args[0]});
            std.process.exit(1);
        }
        try account.AccountInfo.remove(bank_directory, bankdata_file, username.?, true);
    }
}   