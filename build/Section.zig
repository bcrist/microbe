name: []const u8,
contents: []const []const u8,
start_alignment_bytes: ?u32 = 4,
end_alignment_bytes: ?u32 = 4,
rom_region: ?[]const u8 = null,
ram_region: ?[]const u8 = null,
rom_address: ?u32 = null,
ram_address: ?u32 = null,
init_value: ?u8 = null,
skip_init: bool = false, // used by RP2040 boot2 section (it gets loaded by the built-in ROM instead)

pub fn is_align4(self: Section) bool {
    return self.start_alignment_bytes == 4 and self.end_alignment_bytes == 4;
}

pub fn keep_rom_section(comptime name: []const u8, comptime rom_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "KEEP(*(." ++ name ++ "*))"
        },
        .rom_region = rom_region,
    };
}

pub fn rom_section(comptime name: []const u8, comptime rom_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "*(." ++ name ++ "*)"
        },
        .rom_region = rom_region,
    };
}

pub fn initialized_ram_section(comptime name: []const u8, comptime rom_region: []const u8, comptime ram_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "*(." ++ name ++ "*)"
        },
        .rom_region = rom_region,
        .ram_region = ram_region,
    };
}

pub fn uninitialized_ram_section(comptime name: []const u8, comptime ram_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "*(." ++ name ++ "*)"
        },
        .ram_region = ram_region,
    };
}

pub fn zeroed_ram_section(comptime name: []const u8, comptime ram_region: []const u8) Section {
    return .{
        .name = name,
        .contents = &.{
            "*(." ++ name ++ "*)"
        },
        .ram_region = ram_region,
        .init_value = 0,
    };
}

pub fn default_vector_table_section() Section {
    return keep_rom_section("vector_table", "flash");
}

pub fn default_text_section() Section {
    return rom_section("text", "flash");
}

pub fn default_rodata_section() Section {
    return rom_section("rodata", "flash");
}

pub fn default_nvm_section() Section {
    return rom_section("nvm", "flash");
}

pub fn default_data_section() Section {
    return initialized_ram_section("data", "flash", "ram");
}

pub fn default_bss_section() Section {
    return zeroed_ram_section("bss", "ram");
}

pub fn default_udata_section() Section {
    return uninitialized_ram_section("udata", "ram");
}

pub fn default_heap_section() Section {
    return uninitialized_ram_section("heap", "ram");
}

pub fn stack_section(comptime name: []const u8, comptime ram_region: []const u8, comptime stack_size: usize) Section {
    const aligned_stack_size = std.mem.alignForward(usize, stack_size, 8);
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

pub fn default_stack_section(comptime stack_size: usize) Section {
    return stack_section("stack", "ram", stack_size);
}

pub fn default_arm_extab_section() Section {
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

pub fn default_arm_exidx_section() Section {
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

pub fn default_arm_sections(comptime stack_size: usize) []const Section {
    return comptime &.{
        // FLASH only:
        default_vector_table_section(),
        default_text_section(),
        default_arm_extab_section(),
        default_arm_exidx_section(),
        default_rodata_section(),

        // RAM only:
        // Stack goes first to avoid overflows silently corrupting data; instead
        // they'll generally cause a fault when trying to write outside of ram.
        // Note this assumes the usual downward-growing stack convention.
        default_stack_section(stack_size),

        // FLASH + RAM:
        default_data_section(),

        // RAM only:
        default_bss_section(),
        default_udata_section(),
        default_heap_section(),

        // FLASH only:
        default_nvm_section(),
    };
}

const Section = @This();
const std = @import("std");
