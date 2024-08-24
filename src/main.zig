const std = @import("std");
const account = @import("account.zig");
const UUID = @import("UUID.zig").UUID;
const cli = @import("console/cli.zig");
const panels = @import("cliPanels.zig");
const debug = @import("console/debug.zig");
const hashEqual = @import("encrypter.zig").hashEqual;

const style = cli.ansi.style;

const allocator = std.heap.page_allocator;

const StartOptions = enum {
    signup,
    login,
    exit
};

fn mainPanel(accounts: *std.ArrayList(account.AccountInfo), bank_directory: std.fs.Dir, bankdata_file: std.fs.File) void {
    while (true) {
        const option: StartOptions = cli.getOption("Option: ", StartOptions, cli.index_flag | cli.name_flag) catch |err| {
            debug.logger.err("Failed to get option due to: {any}. Try Again!", .{err});
            continue;
        };
        var userdata: account.AccountData = undefined;
        switch (option) {
            .login => {
                const success = panels.loginCLI(allocator, null, accounts.items, bank_directory, &userdata) catch |err| {
                    switch (err) {
                        error.AccountFileNotFound => debug.logger.err("Account Not Found!", .{}),
                        error.TextTooBig => debug.logger.err("Text Too Big!", .{}),
                        error.EndOfFile =>  debug.logger.err("Unexpected End Of File!", .{}),
                        error.Undefined => debug.logger.err("Undefined Behiavor!", .{}),
                        error.Unexpected => debug.logger.err("Unexpected Error!", .{}),
                        else => debug.logger.err("{any}", .{err})
                    }
                    return;
                };
                if (success) {
                    cli.bell();
                    panels.openUserPanelCLI(allocator, &userdata, accounts.items, bank_directory);
                } else {
                    debug.logger.err("Invalid Username or Passowrd!", .{});
                }
            },
            .signup => {
                const success = panels.signupCLI(allocator, null, accounts.items, bankdata_file, bank_directory, &userdata) catch |err| {
                    debug.logger.err("{any} when creating account!", .{err});
                    continue;
                };
                if (success) {
                    cli.bell();
                    accounts.append(userdata.info) catch |err| {
                        debug.logger.err("Failed to append account to list due to: {any}", .{err});
                        continue;
                    };
                    panels.openUserPanelCLI(allocator, &userdata, accounts.items, bank_directory);
                } else {
                    debug.logger.err("Signup failed!", .{});
                }
            },
            .exit => return,
        }
    }
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
    // const command_name = "open";
    // const username: ?[]u8 = null;

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

    debug.logger.info("parsing account...", .{});
    var accounts = account.AccountInfo.parseFile(bankdata_file) catch |err|{ 
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
        var userdata: account.AccountData = undefined;
        const success = panels.signupCLI(allocator, username, accounts.items, bankdata_file, bank_directory, &userdata) catch |err| {
            debug.logger.err("{any} when creating account!", .{err});
            std.process.exit(1);
        };
        if (!success) {
            debug.logger.err("Signup failed!", .{});
            std.process.exit(1);
        }
        panels.openUserPanelCLI(allocator, &userdata, accounts.items, bank_directory);
    } else if (std.mem.eql(u8, command_name, "open")) {
        var userdata: account.AccountData = undefined;
        const success = panels.loginCLI(allocator, username, accounts.items, bank_directory, &userdata) catch |err| {
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
            panels.openUserPanelCLI(allocator, &userdata, accounts.items, bank_directory);
        } else {
            debug.logger.err("Invalid Username or Passowrd!", .{});
            std.process.exit(1);
        }
    } else if (std.mem.eql(u8, command_name, "start")) {
        mainPanel(&accounts, bank_directory, bankdata_file);
    } else if (std.mem.eql(u8, command_name, "delete")) {
        if (username == null) {
            debug.logger.err("Must specify username!", .{});
            debug.logger.info("Usage: {s} delete <username>", .{args[0]});
            std.process.exit(1);
        }
        try account.AccountInfo.remove(bank_directory, bankdata_file, username.?, true);
    }else {
        debug.logger.fatal("Unknown command: {s}", .{command_name});
        std.process.exit(1);
    }
}   