const std = @import("std");

const MemoryRegion = @This();

offset: usize,
length: usize,
name: []const u8,
access: std.EnumSet(AccessType),

pub const AccessType = enum {
    readable,
    writable,
    executable,
};

pub fn accessMode(what: anytype) std.EnumSet(AccessType) {
    var access = std.EnumSet(AccessType) {};
    inline for (what) |t| {
        access.insert(t);
    }
    return access;
}

pub fn rom(name: []const u8, offset: usize, length: usize) MemoryRegion {
    return .{
        .offset = offset,
        .length = length,
        .name = name,
        .access = accessMode(.{ .readable }),
    };
}

pub fn executableRom(name: []const u8, offset: usize, length: usize) MemoryRegion {
    return .{
        .offset = offset,
        .length = length,
        .name = name,
        .access = accessMode(.{ .readable, .executable }),
    };
}

pub fn ram(name: []const u8, offset: usize, length: usize) MemoryRegion {
    return .{
        .offset = offset,
        .length = length,
        .name = name,
        .access = accessMode(.{ .readable, .writable }),
    };
}

pub fn executableRam(name: []const u8, offset: usize, length: usize) MemoryRegion {
    return .{
        .offset = offset,
        .length = length,
        .name = name,
        .access = accessMode(.{ .readable, .writable, .executable }),
    };
}

pub fn mainFlash(offset: usize, length: usize) MemoryRegion {
    return executableRom("flash", offset, length);
}

pub fn mainRam(offset: usize, length: usize) MemoryRegion {
    return executableRam("ram", offset, length);
}
