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
};
pub const ParseError = error {
    FileToBig,
    PermisonDenied,
    Unexpected,
    Invalid,
    EndOfFile,
} || AccountError;

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
    const name = encrypter.decryptBytes(account_allocator, name_buffer[0..i-1], true);
    account_allocator.free(name_buffer);
    amount_read += i;    
    // now read the id which is a uid with 16 bytes, uid is not encrypted using postitonal encryption
    const id = encrypter.decryptBytes(account_allocator, read_buf[i..][0..16], false);
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
    const encrypted_name = encrypter.encryptBytes(account_allocator, self.name, true);
    defer account_allocator.free(encrypted_name);

    try writer.writeAll(encrypted_name);
    try writer.writeByte(0);

    const encrypted_uid = encrypter.encryptBytes(account_allocator, &self.id.bytes, false);
    defer account_allocator.free(encrypted_uid);

    try writer.writeAll(encrypted_uid);
}

pub fn writeMultiple(file: std.fs.File, accounts: []Self) !void { 
    for (accounts) |acount| try acount.write(file);
}