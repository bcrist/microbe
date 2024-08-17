offset: usize,
length: usize,
name: []const u8,
access: std.EnumSet(Access_Type),

pub const Access_Type = enum {
    readable,
    writable,
    executable,
};

pub fn access_mode(what: anytype) std.EnumSet(Access_Type) {
    var access = std.EnumSet(Access_Type) {};
    inline for (what) |t| {
        access.insert(t);
    }
    return access;
}

pub fn rom(name: []const u8, offset: usize, length: usize) Memory_Region {
    return .{
        .offset = offset,
        .length = length,
        .name = name,
        .access = access_mode(.{ .readable }),
    };
}

pub fn executable_rom(name: []const u8, offset: usize, length: usize) Memory_Region {
    return .{
        .offset = offset,
        .length = length,
        .name = name,
        .access = access_mode(.{ .readable, .executable }),
    };
}

pub fn ram(name: []const u8, offset: usize, length: usize) Memory_Region {
    return .{
        .offset = offset,
        .length = length,
        .name = name,
        .access = access_mode(.{ .readable, .writable }),
    };
}

pub fn executable_ram(name: []const u8, offset: usize, length: usize) Memory_Region {
    return .{
        .offset = offset,
        .length = length,
        .name = name,
        .access = access_mode(.{ .readable, .writable, .executable }),
    };
}

pub fn main_flash(offset: usize, length: usize) Memory_Region {
    return executable_rom("flash", offset, length);
}

pub fn main_ram(offset: usize, length: usize) Memory_Region {
    return executable_ram("ram", offset, length);
}

const Memory_Region = @This();
const std = @import("std");
