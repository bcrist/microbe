const std = @import("std");

pub const chips = @import("chips.zig");
pub const Chip = chips.Chip;
pub const cores = @import("cores.zig");
pub const Core = cores.Core;

pub const MemoryRegion = struct {
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
};

pub fn mainFlash(offset: usize, length: usize) MemoryRegion {
    return .{
        .offset = offset,
        .length = length,
        .name = "flash",
        .access = MemoryRegion.accessMode(.{ .readable, .executable }),
    };
}

pub fn mainRam(offset: usize, length: usize) MemoryRegion {
    return .{
        .offset = offset,
        .length = length,
        .name = "ram",
        .access = MemoryRegion.accessMode(.{ .readable, .writable, .executable }),
    };
}

pub const Section = struct {
    name: []const u8,
    contents: []const []const u8,
    start_alignment_bytes: ?u32 = 4,
    end_alignment_bytes: ?u32 = 4,
    rom_region: ?[]const u8 = null,
    ram_region: ?[]const u8 = null,
    init_value: ?u8 = null,
};

pub fn defaultVectorTableSection() Section { comptime {
    return .{
        .name = "vector_table",
        .contents = &.{
            "KEEP(*(.vector_table))"
        },
        .rom_region = "flash",
    };
}}

pub fn defaultTextSection() Section { comptime {
    return .{
        .name = "text",
        .contents = &.{
            "*(.text*)",
        },
        .rom_region = "flash",
    };
}}

pub fn defaultArmExtabSection() Section { comptime {
    return .{
        .name = "ARM.extab",
        .contents = &.{
            "*(.ARM.extab* .gnu.linkonce.armextab.*)",
        },
        .start_alignment_bytes = null,
        .end_alignment_bytes = null,
        .rom_region = "flash",
    };
}}

pub fn defaultArmExidxSection() Section { comptime {
    return .{
        .name = "ARM.exidx",
        .contents = &.{
            "*(.ARM.exidx* .gnu.linkonce.armexidx.*)",
        },
        .start_alignment_bytes = null,
        .end_alignment_bytes = null,
        .rom_region = "flash",
    };
}}

pub fn defaultRoDataSection() Section { comptime {
    return .{
        .name = "rodata",
        .contents = &.{
            "*(.rodata*)",
        },
        .rom_region = "flash",
    };
}}

pub fn defaultNvmSection() Section { comptime {
    return .{
        .name = "nvm",
        .contents = &.{},
        .rom_region = "flash",
    };
}}

pub fn defaultStackSection(comptime stack_size: usize) Section { comptime {
    var aligned_stack_size = std.mem.alignForward(stack_size, 8);
    return .{
        .name = "stack",
        .contents = &.{
            std.fmt.comptimePrint(". = . + {};", .{ aligned_stack_size }),
        },
        .start_alignment_bytes = 8,
        .end_alignment_bytes = null,
        .ram_region = "ram",
    };
}}

pub fn defaultDataSection() Section { comptime {
    return .{
        .name = "data",
        .contents = &.{
            "*(.data*)",
        },
        .rom_region = "flash",
        .ram_region = "ram",
    };
}}

pub fn defaultBssSection() Section { comptime {
    return .{
        .name = "bss",
        .contents = &.{
            "*(.bss*)",
        },
        .ram_region = "ram",
        .init_value = 0,
    };
}}

pub fn defaultUDataSection() Section { comptime {
    return .{
        .name = "udata",
        .contents = &.{
            "*(.udata*)",
        },
        .ram_region = "ram",
    };
}}

pub fn defaultHeapSection() Section { comptime {
    return .{
        .name = "heap",
        .contents = &.{},
        .ram_region = "ram",
    };
}}

pub fn defaultSections(comptime stack_size: usize) []const Section { comptime {
    return &[_]Section {
        // FLASH only:
        defaultVectorTableSection(),
        defaultTextSection(),
        defaultArmExtabSection(),
        defaultArmExidxSection(),
        defaultRoDataSection(),

        // RAM only:
        // Stack goes first to avoid overflows silently corrupting data; instead
        // they'll generally cause a fault when trying to write outside of ram.
        // Note this assumes the usual downward-growing stack convention.
        defaultStackSection(stack_size),

        // FLASH + RAM:
        defaultDataSection(),

        // RAM only:
        defaultBssSection(),
        defaultUDataSection(),
        defaultHeapSection(),

        // FLASH only:
        defaultNvmSection(),
    };
}}
