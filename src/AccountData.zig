const std = @import("std");
const encrypter = @import("encrypter.zig");
const AccountInfo = @import("AccountInfo.zig");

const allocator = AccountInfo.account_allocator;
const Self = @This();
const undefined_email = "UNDEFINED";

// everthing will be created manually, we will have to free everything in this structure
// and will free the stuff in the acount info to
is_admin: bool = false,
info: AccountInfo,
email: []const u8, // this will be encrypted
password: []const u8, // this will only be hashed we wont ever store the actual account password
balance: *f64, // this wont be encrypted
file: std.fs.File,

const UnexpectedError = error{Unexpected, Undefined};

pub const FileError = error {
    OutOfMemory,
    DeviceBusy,
    FileTooBig,
    EndOfFile,
} || UnexpectedError;

pub const CreateError = error {
    AccountInfoMissing,
    AccountAlreadyExists,
} || UnexpectedError || FileError;

pub fn writeToFile(self: *const Self) FileError!void {
    
    self.file.seekTo(0) catch |e| switch (e) {
        error.AccessDenied, error.Unseekable => return error.DeviceBusy,
        else => return error.Unexpected
    };

    const writer = self.file.writer();
    const encrypted_email = encrypter.encryptBytes(allocator, self.email, true) catch @panic("Out of Memory!");
    defer allocator.free(encrypted_email);
    const err = write_block: {
        writer.writeAll(encrypted_email) catch |e| break :write_block e;
        writer.writeByte(0) catch |e| break :write_block e;
        
        writer.writeAll(self.password) catch |e| break :write_block e;
        writer.writeByte(0) catch |e| break :write_block e;

        const balance_bytes = std.mem.toBytes(self.balance.*);
        writer.writeAll(&balance_bytes) catch |e| break :write_block e;
        return;
    };
    switch (err) {
        // handle errors, the rest will be a Unexpected behiavor error
        error.FileTooBig, error.NoSpaceLeft => return error.OutOfMemory,
        error.DeviceBusy => return error.DeviceBusy,
        error.DiskQuota, error.InputOutput, error.InvalidArgument => return error.Undefined,
        else => return error.Unexpected
    }
}

/// return `FileError` if failed to save
pub fn giveMoney(account_data: *Self, money: f64) FileError!void {
    account_data.balance.* += money;
    try account_data.writeToFile();
}

// this functions will check if the user is an admin by using an array of usernames
fn isAdmin(username: []const u8) bool {
    const admins = [_][]const u8 {
        "admin_levi",
        "admin"
    };

    for (admins) |admin| {
        if (std.mem.eql(u8, username, admin)) return true;
    }
    return false;
}

/// creates a account
pub fn create(directory: std.fs.Dir, info: AccountInfo, email: []const u8, password: []const u8, balance: f64, auto_hash: bool) CreateError!Self {
    const filename = std.fmt.allocPrint(allocator, "{}", .{info.id.*}) catch return CreateError.OutOfMemory;
    defer allocator.free(filename);


    const file = directory.createFile(filename, .{ .read = true, .mode = 0o666 }) catch |err| switch (err) {
        error.PathAlreadyExists, error.DeviceBusy => return error.AccountAlreadyExists,
        error.NameTooLong, error.FileTooBig, error.NoSpaceLeft => return error.OutOfMemory,
        else => return error.Unexpected
    };
    const dupe_email = allocator.dupe(u8, email) catch return error.OutOfMemory;
    const dupe_password = if (auto_hash) (encrypter.hashBytes(allocator, password) catch @panic("Out of memory!"))
                                else allocator.dupe(u8, password) catch return error.OutOfMemory;
    const dupe_balance = allocator.create(f64) catch return error.OutOfMemory;
    dupe_balance.* = balance;
    const account = Self{
        .info = info,
        .email = dupe_email,
        .password = dupe_password,
        .balance = dupe_balance,
        .file = file,
        .is_admin = isAdmin(info.name)
    };
    try account.writeToFile();
    return account;
}

pub fn createEmpty(directory: std.fs.Dir, info: AccountInfo, password: []const u8, auto_hash: bool) CreateError!Self {
    const filename = std.fmt.allocPrint(allocator, "{}", .{info.id.*}) catch return CreateError.OutOfMemory;
    defer allocator.free(filename);

    const file = directory.createFile(filename, .{ .read = true, .mode = 0o666 }) catch |err| switch (err) {
        error.PathAlreadyExists, error.DeviceBusy => return error.AccountAlreadyExists,
        error.NameTooLong, error.FileTooBig, error.NoSpaceLeft => return error.OutOfMemory,
        else => return error.Unexpected
    };

    const email = allocator.dupe(u8, undefined_email) catch return error.OutOfMemory;
    const dupe_password = if (auto_hash) (encrypter.hashBytes(allocator, password) catch @panic("Out of memory!"))
                                else allocator.dupe(u8, password) catch return error.OutOfMemory;    
    const balance = allocator.create(f64) catch return error.OutOfMemory;
    balance.* = 0;
    const account = Self{
        .info = info,
        .email = email,
        .password = dupe_password,
        .balance = balance,
        .file = file,
        .is_admin = isAdmin(info.name)
    };
    try account.writeToFile();
    return account;
}

pub const OpenError = error{
    TextTooBig,
    AccountFileNotFound
} || UnexpectedError || AccountInfo.ParseError || FileError;

pub fn open(directory: std.fs.Dir, info: AccountInfo) OpenError!Self {
    const filename = std.fmt.allocPrint(allocator, "{}", .{info.id.*}) catch return CreateError.OutOfMemory;
    defer allocator.free(filename);

    const file = directory.openFile(filename, .{ .mode = .read_write }) catch |err| switch (err) {
        error.PathAlreadyExists, error.DeviceBusy, error.FileBusy, error.PipeBusy => return error.DeviceBusy,
        error.NameTooLong, error.FileTooBig, error.NoSpaceLeft => return error.OutOfMemory,
        error.FileNotFound => return error.AccountFileNotFound,
        error.BadPathName, error.Unexpected, error.AccessDenied => return error.Undefined,
        else => return error.Unexpected
    };

    const read_buf = file.readToEndAlloc(allocator, 1024*1024) catch |err| switch (err) {
        error.FileTooBig => return error.FileTooBig,
        else => return error.Unexpected
    };
    defer allocator.free(read_buf);

    // create two buffers
    const buffer_length = 1024;
    const email_buf = allocator.alloc(u8, buffer_length) catch return error.OutOfMemory;
    const password_buf = allocator.alloc(u8, buffer_length) catch return error.OutOfMemory;

    defer allocator.free(email_buf);
    defer allocator.free(password_buf);

    var i: usize = 0;
    var c: u8 = undefined;
    while (c != 0) : (i += 1) {
        if (i >= read_buf.len) return error.EndOfFile;
        c = read_buf[i];

        if (i >= buffer_length) return error.TextTooBig;
        email_buf[i] = c;
    }
    const email_len: usize = i;
    c = undefined;
    while (c != 0) : (i += 1) {
        if (i >= read_buf.len) return error.EndOfFile;
        c = read_buf[i];

        if (i >= buffer_length) return error.TextTooBig;
        password_buf[i-email_len] = c;
    }
    const passowrd_len: usize = i - email_len;
    // all the buffers should have data and now we gotta decrypt it, but not the password
    const email: []u8 = getemail: {
        const e = encrypter.decryptBytes(allocator, email_buf[0..email_len-1], true) catch @panic("Out of Memory!");
        if (std.mem.eql(u8, e, undefined_email))
            break :getemail &[0]u8{};
        break :getemail e;
    };

    const password = allocator.dupe(u8, password_buf[0..passowrd_len-1]) catch return error.OutOfMemory;

    // now we need to get balance which is not encrypted
    const balance = allocator.create(f64) catch return error.OutOfMemory;
    balance.* = std.mem.bytesToValue(f64, read_buf[i..]);

    return .{
        .info = info,
        .email = email,
        .password = password,
        .balance = balance,
        .file = file,
        .is_admin = isAdmin(info.name)
    };
}

// must be called at end of use
pub fn close(self: *Self) void {
    self.file.close();                                          
    allocator.free(self.email);
    allocator.free(self.password);
    allocator.destroy(self.balance);
}

pub fn closeAll(self: *Self) void {
    self.info.close();
    self.close();
}