const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

/// This function will copy the `bytes` array using `allocator`, the owner is the caller!
/// 
/// Encrypt a array of bytes using a allgrithme that can easily be decrypted, if `positional` is true then it will use positional encryption
/// and will change the bytes deppeding on there order in the array!
/// 
/// Will return `error.OutOfMemory` if needed!
pub fn encryptBytes(allocator: Allocator, bytes: []const u8, positional: bool) Allocator.Error![]u8 {
    const new_bytes = try allocator.dupe(u8, bytes);
    for (new_bytes, 0..) |byte, index| {
        const postion_offset: u8 = (@as(u8, @truncate(index)) *% 0xFF +% 0x12) ^ 'O';
        var b = byte +% @as(u8, 32) *% 64;
        b +%= if (positional) postion_offset else 0x1A;
        b ^= 0x32;
        b -%= 25;
        b ^= 0xFF;
        b +%= (64 +% 32);
        b -%= @as(u8, 'F') +% 'U' +% 'C' +% 'K' +% ' ' +% 'Y' +% 'O' +% 'U';
        new_bytes[index] = b;
    }
    return new_bytes;
}

/// This function will copy the `bytes` array using `allocator`, the owner is the caller!
/// 
/// Decrypt a array of bytes using a allgrithme that use to invert the `encryptBytes`, if `positional` is true then it will use positional encryption
/// and will change the bytes deppeding on there order in the array!
/// 
/// Will return `error.OutOfMemory` if needed!
pub fn decryptBytes(allocator: Allocator, bytes: []const u8, positional: bool) Allocator.Error![]u8 {
    const new_bytes = try allocator.dupe(u8, bytes);
    for (new_bytes, 0..) |byte, index| {
        const postion_offset: u8 = (@as(u8, @truncate(index)) *% 0xFF +% 0x12) ^ 'O';
        // var b = byte;
        var b = byte +% (@as(u8, 'F') +% 'U' +% 'C' +% 'K' +% ' ' +% 'Y' +% 'O' +% 'U');
        b -%= 64 +% 32;
        b ^= 0xFF; // flips the bytes
        b +%= 25;
        b ^= 0x32;
        b -%= if (positional) postion_offset else 0x1A;
        b -%= @as(u8, 32) *% 64;
        new_bytes[index] = b;
    }

    return new_bytes;
}

test "decrypt/encrypt bytes" {
    const ally = std.testing.allocator;

    const encrypt_string = "Hello, world!";
    const pos_encrypt = try encryptBytes(ally, encrypt_string, true);
    const nonpos_encrypt = try encryptBytes(ally, encrypt_string, false);
    defer ally.free(pos_encrypt);
    defer ally.free(nonpos_encrypt);

    const pos_decrypt = try decryptBytes(ally, pos_encrypt, true);
    const nonpos_decrypt = try decryptBytes(ally, nonpos_encrypt, false);
    defer ally.free(pos_decrypt);
    defer ally.free(nonpos_decrypt);

    try std.testing.expectEqualSlices(u8, encrypt_string, pos_decrypt);
    try std.testing.expectEqualSlices(u8, encrypt_string, nonpos_decrypt);
}

/// This function will copy the `bytes` array using `allocator`, the owner is the caller!
/// 
/// Hash a array of bytes using a allgrithme that use to make it very hard to decrypt the hash.
/// Will return `error.OutOfMemory` if needed!
pub fn hashBytes(allocator: Allocator, bytes: []const u8) Allocator.Error![]u8 {
    const new_bytes = try allocator.dupe(u8, bytes);
    for (new_bytes, 0..) |byte, index| {
        // var b = byte;
        var b = byte +% (@as(u8, 'F') +% 'U' +% 'C' +% 'K' +% ' ' +% 'Y' +% 'O' +% 'U');
        b -%= 64 +% 32;
        b *%= 0xAA;
        // b ^= 0xFF; // flips the bytes
        b +%= 25 +% byte;
        b ^= 0x32;
        b -%= 0x1A -% byte;
        b -%= @as(u8, 32) *% 64;
        b *%= 32;
        b +%= if (b == 0) 12+%byte else 16+%byte;
        // b <<= 2;
        new_bytes[index] = b;
    }

    return new_bytes;
}

pub fn hashEqual(allocator: Allocator, hash: []const u8, bytes: []const u8) Allocator.Error!bool {
    const bytes_hashed = try hashBytes(allocator, bytes);
    defer allocator.free(bytes_hashed);
    return mem.eql(u8, hash, bytes_hashed);
}

fn testHashEqual(allocator: Allocator, hash: []const u8, bytes: []const u8) !void {
    const bytes_hashed = try hashBytes(allocator, bytes);
    defer allocator.free(bytes_hashed);
    try std.testing.expectEqualSlices(u8, hash, bytes_hashed);
}
test "hash equality" {
    const ally = std.testing.allocator;
    const string = "Hello, world!";
    const hash_bytes = try hashBytes(ally, string);
    defer ally.free(hash_bytes);

    try testHashEqual(ally, hash_bytes, string);
}