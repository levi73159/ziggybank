const std = @import("std");
const encrypter = @import("encrypter.zig");
const UUID = @import("UUID.zig").UUID;

const Self = @This();

pub const name_max_length = 256;

pub const account_allocator = std.heap.page_allocator;

name: []const u8,
id: *UUID,

const AccountError = error {
    NameTooBig,
    AccountNotFound,
};
pub const ParseError = error {
    FileToBig,
    PermisonDenied,
    Unexpected,
    Invalid,
    EndOfFile,
} || AccountError;

pub fn remove(directory: std.fs.Dir, file: std.fs.File, name: []const u8, remove_data_file: bool) !void {
    try file.seekTo(0);
    var read_buf = file.readToEndAlloc(account_allocator, 2048*2048) catch |e| switch (e) {
        error.FileTooBig => return ParseError.FileToBig,
        else => return ParseError.Unexpected
    };
    defer account_allocator.free(read_buf);

    
    // first get the position of the account in the file
    const account_position = try findAccount(read_buf, name);
    if (account_position == null) {
        return error.AccountNotFound;
    }
    const end_position: usize = account_position.?.pos + account_position.?.size;
    // now we have position so we want to read the entire file buffer into memory again and then remove 
    // the account from it and move the other line to the older positon
    if (end_position < read_buf.len) { 
        const ahead = read_buf[end_position..];
        std.mem.copyForwards(u8, read_buf[account_position.?.pos..], ahead);

        
        try file.seekTo(0);
        try file.writeAll(read_buf);
        try file.setEndPos(ahead.len + account_position.?.pos);
    } else {
       try file.setEndPos(account_position.?.pos);
    }

    if (remove_data_file) {
        const filename = try std.fmt.allocPrint(account_allocator, "{}", .{account_position.?.self.id.*});
        defer account_allocator.free(filename);

        try directory.deleteFile(filename);
    }
}

/// creates a new account and `@panic`s if we are out of memory;
pub fn create(name: []const u8, id: UUID) Self {
    const new_name = account_allocator.dupe(u8, name) catch @panic("out of memory");
    const new_id = account_allocator.create(UUID) catch @panic("out of memory");
    new_id.* = id;

    return .{
        .name = new_name,
        .id = new_id
    };
}

fn parse(read_buf: []u8, account_out: *Self) ParseError!usize {

    var amount_read: usize = 0;

    // start by reading the name which is zero terminated
    const name_buffer: []u8 = account_allocator.alloc(u8, name_max_length) catch @panic("Out of memory!");
    var i: usize = 0;
    var c: u8 = undefined;
    while (c != 0) : (i += 1) {
        if (i >= read_buf.len) return error.EndOfFile;
        c = read_buf[i];

        if (i >= name_buffer.len) return error.NameTooBig;
        name_buffer[i] = c;
    }
    const name = encrypter.decryptBytes(account_allocator, name_buffer[0..i-1], true) catch @panic("Out Of Memory!");
    account_allocator.free(name_buffer);
    amount_read += i;    
    // now read the id which is a uid with 16 bytes, uid is not encrypted using postitonal encryption
    const id = encrypter.decryptBytes(account_allocator, read_buf[i..][0..16], false) catch @panic("Out of Memory!");
    defer account_allocator.free(id);

    if (id.len != 16) return error.Invalid;

    var uuid_bytes: [16]u8 = undefined;
    for (&uuid_bytes, id) |*x, y| {
        x.* = y;
    }

    amount_read += 16;

    // create a UIDD in memory
    const uuid = account_allocator.create(UUID) catch @panic("NEEDS MEMORY!");
    uuid.* = UUID{.bytes = uuid_bytes};

    account_out.* = .{.name=name, .id=uuid};
    return amount_read;
}

/// read the account info in `file` into the memory, if failed return a `ParseError` and if out of memory `@painc`
pub fn parseFile(file: std.fs.File) ParseError!std.ArrayList(Self) {
    // read the file and parse the name first then the id
    const read_buf = file.readToEndAlloc(account_allocator, 2048*2048) catch |e| switch (e) {
        error.FileTooBig => return ParseError.FileToBig,
        else => return ParseError.Unexpected
    };
    defer account_allocator.free(read_buf);
    
    var offset: usize = 0;
    var account_list = std.ArrayList(Self).init(account_allocator);
    
    while (offset < read_buf.len) {
        var account: Self = undefined;
        const read_amount = try parse(read_buf[offset..], &account);
        offset += read_amount;
        account_list.append(account) catch @panic("Out of Memory!");
    }
    return account_list;
}

const AccountPositionInfo = struct {
    self: Self,
    pos: usize,
    size: usize,
};
/// finds the account position in the file, returns `null` if not found, returns an error if failed to parse the file
fn findAccount(read_buf: []u8, name: []const u8) ParseError!?AccountPositionInfo {
    var offset: usize = 0;
    while (offset < read_buf.len) {
        var account: Self = undefined;
        const read_amount = try parse(read_buf[offset..], &account);
        if (std.mem.eql(u8, account.name, name)) {
            // we have found the correct account
            return AccountPositionInfo{ .self = account, .pos = offset, .size = read_amount };
        }

        offset += read_amount;
    }
    return null;
}

/// must be called at end cause it will free the name and the id bytes
pub fn close(self: *Self) void {
    account_allocator.destroy(self.id);
    account_allocator.free(self.name);

    self.id = undefined;
    self.name = undefined;
}

const WriteAccountError = error {
} || std.fs.File.WriteError;

pub fn write(self: Self, file: std.fs.File) WriteAccountError!void {
    const writer = file.writer();
    // Parse the int into bytes
    const encrypted_name = encrypter.encryptBytes(account_allocator, self.name, true) catch @panic("Out Of Memory!");
    defer account_allocator.free(encrypted_name);

    try writer.writeAll(encrypted_name);
    try writer.writeByte(0);

    const encrypted_uid = encrypter.encryptBytes(account_allocator, &self.id.bytes, false) catch @panic("Out Of Memory!");
    defer account_allocator.free(encrypted_uid);

    try writer.writeAll(encrypted_uid);
}

pub fn writeMultiple(file: std.fs.File, accounts: []Self) !void { 
    for (accounts) |acount| try acount.write(file);
}

pub inline fn getAccount(name: []const u8, users_lookup: []Self) ?Self {
    for (users_lookup) |user| {
        if (std.mem.eql(u8, name, user.name)) return user;
    }
    return null;
}