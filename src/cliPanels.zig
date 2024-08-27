const account = @import("account.zig");
const cli = @import("console/cli.zig");
const debug = @import("console/debug.zig");
const std = @import("std");
const hashEqual = @import("encrypter.zig").hashEqual;
const UUID = @import("UUID.zig").UUID;

const UserOptions = enum { transaction, widthdraw, info, update_account, exit };
const AdminOptions = enum { give_money, take_money, add_user, remove_user, modify_account, list, clear, exit };

// helpful function
fn printAccount(account_data: *const account.AccountData) void {
    debug.logger.print("Name: {s}, Email: {s}, Balance: {d:.2}, Admin: {}, UUID: {}\n", .{ account_data.info.name, account_data.email, account_data.balance.*, account_data.is_admin, account_data.info.id.* });
}

/// returns error.Exited if user types in '_exit'
pub fn getAccountCLI(allocator: std.mem.Allocator, askstr: ?[]const u8, users_lookup: []account.AccountInfo) !account.AccountInfo {
    while (true) {
        const name = cli.readLineAlloc(allocator, askstr, false, account.name_max_length) catch |err| {
            debug.logger.err("Failed to get input due to: {any}. Try Again!", .{err});
            continue;
        };
        defer allocator.free(name);

        if (std.mem.eql(u8, name, "_exit")) {
            return error.Exited;
        }

        const maybe_account = account.AccountInfo.getAccount(name, users_lookup);
        if (maybe_account) |acc| {
            return acc;
        } else {
            debug.logger.err("User not found! Try Again!", .{});
            continue;
        }
    }
}

pub fn transactionCLI(allocator: std.mem.Allocator, account_data: *account.AccountData, users_lookup: []account.AccountInfo, directory: std.fs.Dir) bool {
    // get the name from the user
    while (true) {
        const reciver_user = getAccountCLI(allocator, "Send Money To? ", users_lookup) catch return false;

        var reciver_data = account.AccountData.open(directory, reciver_user) catch |err| {
            debug.logger.fatal("{any}", .{err});
            cli.pause(); // pause so the user can see the error
            return false;
        };

        const amount_to_give = blk: {
            while (true) {
                const x = cli.readLineAlloc(allocator, "Amount: ", false, 100) catch continue;
                defer allocator.free(x);
                const amount = std.fmt.parseFloat(f64, x) catch continue;

                break :blk amount;
            }
        };

        if (amount_to_give > account_data.balance.*) {
            debug.logger.fatal("Failed to go throught with transaction, Reason: Not enought money!", .{});
            debug.logger.fatal("Aborting!", .{});
            cli.pause();
            return false;
        }

        // now we want to check if the user is sure about the transaction
        debug.logger.info("We are giving {d:.2} and to {s} and have {d:.2} currently!", .{ amount_to_give, reciver_user.name, account_data.balance.* });
        debug.logger.info("After we will have {d:.2}", .{account_data.balance.* - amount_to_give});
        const conform = cli.getBool("Are you sure?", false) catch |err| {
            debug.logger.fatal("Failed to Go through with transaction, Reason: {any}", .{err});
            debug.logger.fatal("Aborting!", .{});
            cli.pause();
            return false;
        };

        if (conform) {
            reciver_data.giveMoney(amount_to_give) catch |err| {
                debug.logger.fatal("Failed To Save Transaction: {any}", .{err});
                cli.pause();
                return false;
            };
            account_data.giveMoney(-amount_to_give) catch |err| {
                debug.logger.fatal("Failed To Save Transaction: {any}", .{err});
                cli.pause();
                return false;
            };
            return true;
        } else {
            // OLD: debug.logger.info("Transaction Aborted!", .{});
            return false;
        }
    }
}

pub fn withdrawCLI(allocator: std.mem.Allocator, account_data: *account.AccountData) bool {
    const WithdrawOptions = enum(u64) {
        // 10, 20, 50, 100, custom
        x10 = 10,
        x20 = 20,
        x50 = 50,
        x100 = 100,
        all = 99999999,
        custom = 0,
    };

    // get the amount of money we want to transaction
    const option = cli.getOption("Select Option", WithdrawOptions, cli.index_flag | cli.value_flag) catch |err| {
        debug.logger.err("Failed to get option due to {any}, please try again.", .{err});
        cli.pause();
        return false;
    };

    const amount_to_take: f64 = blk: {
        if (option == .custom) {
            while (true) {
                const x = cli.readLineAlloc(allocator, "Custom Amount: ", false, 100) catch continue;
                defer allocator.free(x);
                const amount = std.fmt.parseFloat(f64, x) catch continue;

                break :blk amount;
            }
        } else if (option == .all) {
            break :blk account_data.balance.*;
        } else {
            const int_amount: u64 = @intFromEnum(option);
            break :blk @floatFromInt(int_amount); // this is a hack to convert the u64 to a f64
        }
    };

    // check if we have enought money
    if (amount_to_take > account_data.balance.*) {
        debug.logger.fatal("Failed to go throught with withdraw, Reason: Not enough money!", .{});
        debug.logger.fatal("Aborting!", .{});
        cli.pause();
        return false;
    }

    const conform = cli.getBool("Are you sure?", false) catch |err| {
        debug.logger.fatal("Failed to proceed with withdraw, Reason: {any}", .{err});
        debug.logger.fatal("Aborting!", .{});
        cli.pause();
        return false;
    };

    if (conform == false) {
        debug.logger.info("Withdraw Aborted!", .{});
        cli.pause();
        return false;
    }

    if (amount_to_take == account_data.balance.*) {
        const double_check = cli.getBool("Are you sure you want to widthdraw all your money?", false) catch |err| {
            debug.logger.fatal("Failed to proceed with withdraw, Reason: {any}", .{err});
            debug.logger.fatal("Aborting!", .{});
            cli.pause();
            return false;
        };
        if (double_check == false) {
            debug.logger.info("Widthdraw Aborted!", .{});
            cli.pause();
            return false;
        }
    } else if (amount_to_take > account_data.balance.* - 25) {
        const double_check = cli.getBool("Are you sure you want to widthdraw that much money?", true) catch |err| {
            debug.logger.fatal("Failed to Go through with widthdraw, Reason: {any}", .{err});
            debug.logger.fatal("Aborting!", .{});
            cli.pause();
            return false;
        };
        if (double_check == false) {
            debug.logger.info("Widthdraw Aborted!", .{});
            cli.pause();
            return false;
        }
    }

    account_data.giveMoney(-amount_to_take) catch |err| {
        debug.logger.fatal("Failed To Save Widthdraw: {any}", .{err});
        cli.pause();
        return false;
    };
    return true;
}

pub fn updateAccountCLI(allocator: std.mem.Allocator, account_data: *account.AccountData) bool {
    const UpdateAccountOptions = enum { email, password };

    printAccount(account_data);

    // get the amount of money we want to transaction
    const option: UpdateAccountOptions = cli.getOption("Select Option", UpdateAccountOptions, cli.index_flag | cli.name_flag) catch |err| {
        debug.logger.err("Failed to get option due to {any}, please try again.", .{err});
        cli.pause();
        return false;
    };

    switch (option) {
        .email => {
            const email = cli.readLineAlloc(allocator, "New Email: ", false, account.email_max_length) catch |err| {
                switch (err) {
                    error.StreamTooLong => {
                        debug.logger.err("Email To Long! Try Again!", .{});
                    },
                    else => {
                        debug.logger.err("Failed to get input due to: {any}! Try Again!", .{err});
                    },
                }
                cli.pause();
                return false;
            };
            defer allocator.free(email);
            account_data.setEmail(email) catch |e| {
                debug.logger.err("{any}", .{e}); 
                cli.pause();
                return false;
            };
        },
        .password => {
            const old_pass = cli.readLineAlloc(allocator, "Old Password: ", true, account.name_max_length) catch |err| {
                switch (err) {
                    error.StreamTooLong => {
                        debug.logger.err("Password To Long! Try Again!", .{});
                    },
                    else => {
                        debug.logger.err("Failed to get input due to: {any}! Try Again!", .{err});
                    },
                }
                cli.pause();
                return false;
            };
            defer allocator.free(old_pass);

            if (!(hashEqual(allocator, account_data.password, old_pass) catch |e| std.debug.panic("{any}", .{e}))) {
                debug.logger.err("Password Does Not Match!", .{});
                cli.pause();
                return false;
            }

            const new_pass = cli.readLineAlloc(allocator, "New Password: ", true, account.name_max_length) catch |err| {
                switch (err) {
                    error.StreamTooLong => {
                        debug.logger.err("Password To Long! Try Again!", .{});
                    },
                    else => {
                        debug.logger.err("Failed to get input due to: {any}! Try Again!", .{err});
                    },
                }
                cli.pause();
                return false;
            };
            defer allocator.free(new_pass);
            
            account_data.setPassword(new_pass) catch |e| {
                debug.logger.err("{any}", .{e}); 
                cli.pause();
                return false;
            }; 
        },
    }
    account_data.writeToFile() catch |err| {
        debug.logger.fatal("Failed to update account due to: {any}", .{err});
        cli.pause();
        return false;
    };
    return true;
}

pub fn accountPanelCLI(allocator: std.mem.Allocator, account_data: *account.AccountData, users_lookup: []account.AccountInfo, directory: std.fs.Dir) void {
    while (true) {
        cli.ansi.style.setForeColor(.bright_white);
        cli.ansi.style.printStyle("Account Panel\n", .bold, .{});
        debug.logger.print("Name: {s}\n", .{account_data.info.name});
        debug.logger.print("Balance: {d:.2}\n", .{account_data.balance.*});
        cli.ansi.style.deafultForeColor();
        const option = cli.getOption("Select Option", UserOptions, cli.index_flag | cli.name_flag) catch |err| {
            debug.logger.err("Hey! Failed to get input cause {any}, try again!", .{err});
            continue;
        };
        const success: bool = switch (option) {
            .transaction => transactionCLI(allocator, account_data, users_lookup, directory),
            .widthdraw => withdrawCLI(allocator, account_data),
            .info => blk: {
                printAccount(account_data);
                cli.pause();
                break :blk true;
            },
            .update_account => updateAccountCLI(allocator, account_data),
            .exit => {
                cli.clear();
                return; // exit
            },
        };
        cli.clear();
        if (success) {
            debug.logger.success("{s} Complete!", .{@tagName(option)});
            cli.bell();
        } else {
            debug.logger.info("{s} Aborted!", .{@tagName(option)});
        }
    }
}

fn addUserCLI(allocator: std.mem.Allocator, users: *std.ArrayList(account.AccountInfo), data_file: std.fs.File, directory: std.fs.Dir) void {
    while (true) {
        const name = cli.readLineAlloc(allocator, "username: ", false, account.name_max_length) catch |err| {
            switch (err) {
                error.StreamTooLong => {
                    debug.logger.err("Username To Long! Try Again!", .{});
                },
                else => {
                    debug.logger.err("Failed to get input due to: {any}! Try Again!", .{err});
                },
            }
            continue;
        };
        defer allocator.free(name);

        // check if user exists
        const exists = account.AccountInfo.getAccount(name, users.items) != null;
        if (exists) {
            debug.logger.info("Account already exists!", .{});
            debug.logger.info("Aborting!", .{});
            return;
        }

        // account doesn't exist
        const email = cli.readLineAlloc(allocator, "email? ", false, account.email_max_length) catch |err| {
            switch (err) {
                error.StreamTooLong => {
                    debug.logger.err("Email To Long! Try Again!", .{});
                },
                else => {
                    debug.logger.err("Failed to get input due to: {any}", .{err});
                },
            }
            continue;
        };
        defer allocator.free(email);

        const password = cli.readLineAlloc(allocator, "password? ", true, account.name_max_length) catch |err| {
            switch (err) {
                error.StreamTooLong => {
                    debug.logger.err("Password To Long! Try Again!", .{});
                },
                else => {
                    debug.logger.err("Failed to get input due to: {any}! Try Again!", .{err});
                },
            }
            continue;
        };
        defer allocator.free(password);

        const balance: f64 = inloop: while (true) {
            const input = cli.readLineAlloc(allocator, "Balance: ", false, 100) catch |err| {
                debug.logger.err("Failed to get input, due to: {any}! try again!", .{err});
                continue;
            };

            const float = std.fmt.parseFloat(f64, input) catch {
                debug.logger.fatal("FAILED TO PARSE FLOAT!", .{});
                debug.logger.info("Aborting!", .{});
                return;
            };

            break :inloop float;
        };

        const uuid = blk: {
            loop: while (true) {
                const uuid = UUID.init();
                for (users.items) |user_info| {
                    if (std.mem.eql(u8, &user_info.id.*.bytes, &uuid.bytes)) {
                        continue :loop;
                    }
                }
                break :blk uuid;
            }
        };
        const info = account.AccountInfo.create(name, uuid);
        errdefer info.close();
        info.write(data_file) catch |err| {
            debug.logger.fatal("Failed to write to file due to: {any}!", .{err});
            debug.logger.fatal("Aborting!", .{});
            return;
        };
        users.append(info) catch unreachable;

        var data = account.AccountData.create(directory, info, email, password, balance, true) catch |err| {
            switch (err) {
                // AccountInfoMissing,
                // AccountAlreadyExists
                error.AccountInfoMissing => debug.logger.err("Account Info Missing!", .{}),
                error.AccountAlreadyExists => debug.logger.err("Account Already Exists!", .{}),
                else => debug.logger.err("Failed to create account due to: {any}!", .{err}),
            }
            debug.logger.info("Aborting!", .{});
            return;
        };
        data.close();
        break;
    }
}

fn modifyAccount(allocator: std.mem.Allocator, directory: std.fs.Dir, users_lookup: []account.AccountInfo) void {
    const ModifyAccountOptions = enum { email, balance, password };

    const userinfo = getAccountCLI(allocator, "User: ", users_lookup) catch |err| switch (err) {
        error.Exited => {
            // aborting!
            debug.logger.print("Aborting!\n", .{});
            return;
        },
    };
    var userdata = account.AccountData.open(directory, userinfo) catch |err| {
        debug.logger.err("Failed to get AccountData due to: {any}!", .{err});
        return;
    };
    defer userdata.close();

    // print out the acount data
    // modify account data
    // write account data to file
    printAccount(&userdata);

    while (true) {
        const option: ModifyAccountOptions = cli.getOption("Select Option", ModifyAccountOptions, cli.index_flag | cli.name_flag) catch |err| {
            debug.logger.err("Hey! Failed to get input cause {any}, try again!", .{err});
            continue;
        };
        switch (option) {
            .email => {
                const email = cli.readLineAlloc(allocator, "New Email: ", false, account.email_max_length) catch |err| {
                    switch (err) {
                        error.StreamTooLong => {
                            debug.logger.err("Email To Long! Try Again!", .{});
                        },
                        else => {
                            debug.logger.err("Failed to get input due to: {any}", .{err});
                        },
                    }
                    continue;
                };
                defer allocator.free(email);
                userdata.setEmail(email) catch |e| {
                    debug.logger.err("{any}", .{e});
                    return;
                };
            },
            .balance => {
                const balance: f64 = inloop: while (true) {
                    const input = cli.readLineAlloc(allocator, "New Balance: ", false, 100) catch |err| {
                        debug.logger.err("Failed to get input, due to: {any}! try again!", .{err});
                        continue;
                    };
                    defer allocator.free(input);
                    const float = std.fmt.parseFloat(f64, input) catch {
                        debug.logger.fatal("FAILED TO PARSE FLOAT!", .{});
                        debug.logger.info("Aborting!", .{});
                        return;
                    };
                    break :inloop float;
                };
                userdata.balance.* = balance;
            },
            .password => {
                const password = cli.readLineAlloc(allocator, "New Password: ", true, account.name_max_length) catch |err| {
                    switch (err) {
                        error.StreamTooLong => {
                            debug.logger.err("Password To Long! Try Again!", .{});
                        },
                        else => {
                            debug.logger.err("Failed to get input due to: {any}! Try Again!", .{err});
                        },
                    }
                    continue;
                };
                defer allocator.free(password);
                userdata.setPassword(password) catch |e| {
                    debug.logger.err("{any}", .{e});
                    return;
                };
            },
        }
        break;
    }
    userdata.writeToFile() catch |err| {
        debug.logger.fatal("Failed to write to file due to: {any}!", .{err});
        debug.logger.fatal("Aborting!", .{});
        return;
    };
}

fn handleAdminOptions(allocator: std.mem.Allocator, option: AdminOptions, account_data: *account.AccountData, users: *std.ArrayList(account.AccountInfo), data_file: std.fs.File, directory: std.fs.Dir) bool {
    switch (option) {
        .give_money, .take_money => {
            const user = getAccountCLI(allocator, "User: ", users.items) catch |err| switch (err) {
                error.Exited => {
                    // aborting!
                    debug.logger.print("Aborting!\n", .{});
                    return false;
                },
            };
            var data = account.AccountData.open(directory, user) catch |err| {
                debug.logger.err("Failed to get AccountData due to: {any}!", .{err});
                return false;
            };
            defer data.close();

            // get the amount of money we want to give
            const amount: f64 = blk: while (true) {
                const input = cli.readLineAlloc(allocator, "Amount: ", false, 100) catch |err| {
                    debug.logger.err("Failed to get input, due to: {any}! try again!", .{err});
                    continue;
                };

                const float = std.fmt.parseFloat(f64, input) catch {
                    debug.logger.fatal("FAILED TO PARSE FLOAT!", .{});
                    debug.logger.info("Aborting!", .{});
                    return false;
                };

                break :blk float;
            };

            if (option == .give_money) {
                data.giveMoney(amount) catch |err| {
                    debug.logger.err("Failed to save due to: {any}", .{err});
                    return false;
                };
            } else {
                data.giveMoney(-amount) catch |err| {
                    debug.logger.err("Failed to save due to: {any}", .{err});
                    return false;
                };
            }
        },
        .add_user => addUserCLI(allocator, users, data_file, directory),
        .remove_user => {
            var user = getAccountCLI(allocator, "User: ", users.items) catch |err| switch (err) {
                error.Exited => {
                    // aborting!
                    debug.logger.print("Aborting!", .{});
                    return false;
                },
            };
            defer user.close();
            account.AccountInfo.remove(directory, data_file, user.name, true) catch |err| {
                debug.logger.err("Failed to remove user due to: {any}", .{err});
                return false;
            };
            _ = users.swapRemove(get_index: for (users.items, 0..) |u, i| {
                if (std.mem.eql(u8, user.name, u.name)) break :get_index @as(usize, i);
            } else unreachable);
        },
        .modify_account => modifyAccount(allocator, directory, users.items),
        .clear => cli.clear(),
        .list => account.printUsersToScreen(users.items, directory, account_data),
        .exit => return true,
    }
    return false;
}

pub fn adminPanelCLI(allocator: std.mem.Allocator, account_data: *account.AccountData, users: *std.ArrayList(account.AccountInfo), data_file: std.fs.File, directory: std.fs.Dir) void {
    if (!account_data.is_admin) return; // to pervent hackers or whoever trying to get in the account panel
    while (true) {
        cli.ansi.style.setForeColor(.bright_white);
        cli.ansi.style.printStyle("Admin Panel\n", .bold, .{});
        debug.logger.print("Name: {s}\n", .{account_data.info.name});
        cli.ansi.style.deafultBackColor();

        const option: AdminOptions = cli.getOption("Select Option", AdminOptions, cli.index_flag | cli.name_flag) catch |err| {
            debug.logger.err("Hey! Failed to get input cause {any}, try again!", .{err});
            continue;
        };
        if (handleAdminOptions(allocator, option, account_data, users, data_file, directory)) {
            return;
        }
    }
}

/// Decides wether or not to open account panel or the admin panel
pub fn openUserPanelCLI(allocator: std.mem.Allocator, account_data: *account.AccountData, users: *std.ArrayList(account.AccountInfo), data_file: std.fs.File, directory: std.fs.Dir) void {
    cli.clear();
    if (account_data.is_admin) {
        const use_admin = cli.getBool("Login as admin? ", true) catch |err| {
            debug.logger.err("Failed to get input dude to: {any}", .{err});
            return;
        };
        if (use_admin) {
            adminPanelCLI(allocator, account_data, users, data_file, directory);
        } else {
            accountPanelCLI(allocator, account_data, users.items, directory);
        }
    } else {
        accountPanelCLI(allocator, account_data, users.items, directory);
    }
}

/// return false if user not found
pub fn loginCLI(allocator: std.mem.Allocator, maybe_username: ?[]const u8, users_lookup: []account.AccountInfo, directory: std.fs.Dir, out_data: *account.AccountData) !bool {
    const username = blk: {
        if (maybe_username) |un| {
            break :blk try allocator.dupe(u8, un);
        } else {
            while (true) {
                const un = cli.readLineAlloc(allocator, "username: ", false, account.name_max_length) catch continue;
                break :blk un;
            }
        }
    };
    defer allocator.free(username);

    const password = blk: {
        while (true) {
            debug.logger.print("password: ", .{});
            const pas = cli.readLineAlloc(allocator, null, true, account.name_max_length) catch continue;
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

/// return true if open account
pub fn signupCLI(allocator: std.mem.Allocator, maybe_username: ?[]const u8, users_lookup: []account.AccountInfo, users_file: std.fs.File, directory: std.fs.Dir, out_data: *account.AccountData) !bool {
    const username = blk: {
        if (maybe_username) |un| {
            break :blk try allocator.dupe(u8, un);
        } else {
            while (true) {
                const un = cli.readLineAlloc(allocator, "username: ", false, account.name_max_length) catch continue;
                break :blk un;
            }
        }
    };
    defer allocator.free(username);

    // check if user exists
    var info: account.AccountInfo = undefined;
    const user_exists = blk: for (users_lookup) |user_info| {
        if (std.mem.eql(u8, username, user_info.name)) {
            info = user_info;
            break :blk true;
        }
    } else false;

    if (user_exists) {
        // Check if the user wants to open an existing account
        debug.logger.info("User {s}, already exist! Do you want to open it?", .{username});
        const open = cli.getBool("Open?", false) catch |err| {
            debug.logger.fatal("Failed to get input due to {any}, aborting!", .{err});
            return false;
        };

        if (open) {
            // Prompt for the password
            const password = try cli.readLineAlloc(allocator, "Enter password: ", true, account.name_max_length);
            defer allocator.free(password);

            // Open the account data and verify the password
            const data = try account.AccountData.open(directory, info);
            if (try hashEqual(allocator, data.password, password)) {
                // Password is correct, store the account data and return true
                out_data.* = data;
                return true;
            }
        }

        // Either user chose not to open the account or password is incorrect
        return false;
    }

    const email = try cli.readLineAlloc(allocator, "email? ", false, account.email_max_length);
    defer allocator.free(email);

    const password = try cli.readLineAlloc(allocator, "password? ", true, account.name_max_length);
    defer allocator.free(password);

    const uuid = blk: {
        loop: while (true) {
            const uuid = UUID.init();
            for (users_lookup) |user_info| {
                if (std.mem.eql(u8, &user_info.id.*.bytes, &uuid.bytes)) {
                    continue :loop;
                }
            }
            break :blk uuid;
        }
    };
    info = account.AccountInfo.create(username, uuid);
    errdefer info.close();
    try info.write(users_file);

    out_data.* = try account.AccountData.create(directory, info, email, password, 0, true);
    return true;
}
