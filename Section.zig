const std = @import("std");
const Chip = @import("Chip.zig");
const Core = @import("Core.zig");

const Section = @This();

name: []const u8,
contents: []const []const u8,
start_alignment_bytes: ?u32 = 4,
end_alignment_bytes: ?u32 = 4,
rom_region: ?[]const u8 = null,
ram_region: ?[]const u8 = null,
init_value: ?u8 = null,

pub fn keepRomSection(comptime name: []const u8, comptime rom_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "KEEP(*(." ++ name ++ "*))"
        },
        .rom_region = rom_region,
    };
}

pub fn romSection(comptime name: []const u8, comptime rom_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "*(." ++ name ++ "*)"
        },
        .rom_region = rom_region,
    };
}

pub fn initializedRamSection(comptime name: []const u8, comptime rom_region: []const u8, comptime ram_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "*(." ++ name ++ "*)"
        },
        .rom_region = rom_region,
        .ram_region = ram_region,
    };
}

pub fn uninitializedRamSection(comptime name: []const u8, comptime ram_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "*(." ++ name ++ "*)"
        },
        .ram_region = ram_region,
    };
}

pub fn zeroedRamSection(comptime name: []const u8, comptime ram_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "*(." ++ name ++ "*)"
        },
        .ram_region = ram_region,
        .init_value = 0,
    };
}

pub fn defaultVectorTableSection() Section {
    return keepRomSection("vector_table", "flash");
}

pub fn defaultTextSection() Section {
    return romSection("text", "flash");
}

pub fn defaultRoDataSection() Section {
    return romSection("rodata", "flash");
}

pub fn defaultNvmSection() Section {
    return romSection("nvm", "flash");
}

pub fn defaultDataSection() Section {
    return initializedRamSection("data", "flash", "ram");
}

pub fn defaultBssSection() Section {
    return zeroedRamSection("bss", "ram");
}

pub fn defaultUDataSection() Section {
    return uninitializedRamSection("udata", "ram");
}

pub fn defaultHeapSection() Section {
    return uninitializedRamSection("heap", "ram");
}

pub fn stackSection(comptime name: []const u8, comptime ram_region: []const u8, comptime stack_size: usize) Section {
    var aligned_stack_size = std.mem.alignForward(usize, stack_size, 8);
    return .{
        .name = name,
        .contents = &.{
            std.fmt.comptimePrint(". = . + {};", .{ aligned_stack_size }),
        },
        .start_alignment_bytes = 8,
        .end_alignment_bytes = null,
        .ram_region = ram_region,
    };
}

pub fn defaultStackSection(comptime stack_size: usize) Section {
    return stackSection("stack", "ram", stack_size);
}

pub fn defaultArmExtabSection() Section {
    return .{
        .name = "ARM.extab",
        .contents = &.{
            "*(.ARM.extab* .gnu.linkonce.armextab.*)",
        },
        .start_alignment_bytes = null,
        .end_alignment_bytes = null,
        .rom_region = "flash",
    };
}

pub fn defaultArmExidxSection() Section {
    return .{
        .name = "ARM.exidx",
        .contents = &.{
            "*(.ARM.exidx* .gnu.linkonce.armexidx.*)",
        },
        .start_alignment_bytes = null,
        .end_alignment_bytes = null,
        .rom_region = "flash",
    };
}

pub fn defaultArmSections(comptime stack_size: usize) []const Section {
    return comptime &.{
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
}

pub fn rp2040Boot2Section() Section {
    return .{
        .name = "boot2",
        .contents = &.{
            \\KEEP(*(.boot2))
            \\. = _boot2_start + 0x100;
        },
        .rom_region = "flash",
        .ram_region = "sram5",
    };
}

pub fn defaultRp2040Sections() []const Section {
    return comptime &.{
        // FLASH only:

        rp2040Boot2Section(),
        romSection("boot3", "flash"),
        defaultTextSection(),
        defaultArmExtabSection(),
        defaultArmExidxSection(),
        defaultRoDataSection(),

        // RAM only:

        // We're assuming we'll use the 4KB SRAM4 for core 0 and SRAM5 for core 1.
        // Since those are dedicated memory regions, we don't actually need to specify the size here.
        // Note the first 256 bytes of SRAM5 are also used for the stage2 bootloader
        stackSection("core0_stack", "sram4", 0),
        stackSection("core1_stack", "sram5", 0),

        // FLASH + RAM:
        defaultDataSection(),

        // RAM only:
        defaultBssSection(),
        defaultUDataSection(),
        defaultHeapSection(),

        // FLASH only:
        defaultNvmSection(),
    };
}