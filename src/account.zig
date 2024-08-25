const std = @import("std");
const cli = @import("console/cli.zig");
const debug = @import("console/debug.zig");
pub const AccountData = @import("AccountData.zig");
pub const AccountInfo = @import("AccountInfo.zig");
pub const name_max_length = AccountInfo.name_max_length;
pub const email_max_length = 1280; // 256 * 5 = 1280

pub fn printUsersToScreen(users_lookup: []AccountInfo, directory: std.fs.Dir, exclude: ?*AccountData) void {
    if (exclude) |data| {
        cli.ansi.style.setStyle(.invert);
        debug.logger.print("Name: {s}, Email: {s}, Balance: {d:.2}, Admin: {}, UUID: {}\n", .{data.info.name, 
                                                                                                        data.email, 
                                                                                                        data.balance.*,
                                                                                                        data.is_admin, 
                                                                                                        data.info.id.*});
        cli.ansi.style.removeStyle(.invert);
    }
    
    for (users_lookup) |user_info| {
        
        if (exclude) |data| {
            if (std.mem.eql(u8, data.info.name, user_info.name)) {
                continue;
            }
        }

        // get the account data
        var accountData = AccountData.open(directory, user_info) catch |err| {
            debug.logger.print("Failed to get user: {s}, due to {any}\n", .{user_info.name, err});
            continue;
        };
        defer accountData.close();

        debug.logger.print("Name: {s}, Email: {s}, Balance: {d:.2}, Admin: {}, UUID: {}\n", .{user_info.name, 
                                                                                                        accountData.email, 
                                                                                                        accountData.balance.*,
                                                                                                        accountData.is_admin, 
                                                                                                        user_info.id.*});
    }
}