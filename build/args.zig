pub fn try_chip_args(allocator: std.mem.Allocator, arg_iter: *std.process.ArgIterator, arg: []const u8, chip: *Chip) !bool {
    if (std.mem.eql(u8, arg, "--chip")) {
        chip.name = arg_iter.next() orelse return error.ExpectedChipName;
    } else if (std.mem.eql(u8, arg, "--core") or std.mem.eql(u8, arg, "-c")) {
        const core_name = arg_iter.next() orelse return error.ExpectedCoreName;
        var found_core = false;
        inline for (@typeInfo(Core).Struct.decls) |decl| {
            if (std.mem.eql(u8, core_name, decl.name) or std.mem.eql(u8, core_name, @field(Core, decl.name).name)) {
                chip.core = @field(Core, decl.name);
                found_core = true;
            }
        }
        if (!found_core) {
            return error.InvalidCoreName;
        }
    } else if (std.mem.eql(u8, arg, "--region") or std.mem.eql(u8, arg, "-m")) {
        var region: Memory_Region = .{
            .offset = 0,
            .length = 0,
            .name = "",
            .access = std.EnumSet(Memory_Region.Access_Type).initEmpty(),
        };

        const name_str = arg_iter.next() orelse return error.ExpectedMemoryRegionName;
        const offset_str = arg_iter.next() orelse return error.ExpectedMemoryRegionOffset;
        const length_str = arg_iter.next() orelse return error.ExpectedMemoryRegionLength;
        const access_str = arg_iter.next() orelse return error.ExpectedMemoryRegionAccessFlags;

        region.offset = std.fmt.parseInt(usize, offset_str, 0) catch return error.InvalidMemoryRegionOffset;
        region.length = std.fmt.parseInt(usize, length_str, 0) catch return error.InvalidMemoryRegionLength;
        region.name = name_str;

        for (access_str) |flag| region.access.insert(switch (flag) {
            'r' => .readable,
            'w' => .writable,
            'x' => .executable,
            else => return error.InvalidMemoryRegionAccessFlags,
        });

        const new_regions = try allocator.alloc(Memory_Region, chip.memory_regions.len + 1);
        @memcpy(new_regions.ptr, chip.memory_regions);
        new_regions[new_regions.len - 1] = region;
        chip.memory_regions = new_regions;
    } else if (std.mem.eql(u8, arg, "--entry")) {
        chip.entry_point = arg_iter.next() orelse return error.ExpectedEntryPointName;
    } else if (std.mem.eql(u8, arg, "--multi-core")) {
        chip.single_threaded = false;
    } else if (std.mem.eql(u8, arg, "--extra")) {
        const new_extra = try allocator.alloc(Chip.Extra_Option, chip.extra_config.len + 1);
        @memcpy(new_extra.ptr, chip.extra_config);
        new_extra[new_extra.len - 1] = .{
            .name = arg_iter.next() orelse return error.ExpectedConfigName,
            .value = arg_iter.next() orelse return error.ExpectedConfigValue,
            .escape = false,
        };
    } else if (std.mem.eql(u8, arg, "--extra-escaped")) {
        const new_extra = try allocator.alloc(Chip.Extra_Option, chip.extra_config.len + 1);
        @memcpy(new_extra.ptr, chip.extra_config);
        new_extra[new_extra.len - 1] = .{
            .name = arg_iter.next() orelse return error.ExpectedConfigName,
            .value = arg_iter.next() orelse return error.ExpectedConfigValue,
            .escape = true,
        };
    } else return false;
    return true;
}

pub fn try_section(allocator: std.mem.Allocator, arg_iter: *std.process.ArgIterator, arg: []const u8, sections: *std.ArrayList(Section)) !bool {
    if (std.mem.eql(u8, arg, "--keep-rom")) {
        const name_str = arg_iter.next() orelse return error.ExpectedSectionName;
        const region_str = arg_iter.next() orelse return error.RomRegionName;
        try sections.append(.{
            .name = name_str,
            .contents = &.{
                try std.fmt.allocPrint(allocator, "KEEP(*(.{s}*))", .{ name_str }),
            },
            .rom_region = region_str,
        });
    } else if (std.mem.eql(u8, arg, "--rom")) {
        const name_str = arg_iter.next() orelse return error.ExpectedSectionName;
        const region_str = arg_iter.next() orelse return error.RomRegionName;
        try sections.append(.{
            .name = name_str,
            .contents = &.{
                try std.fmt.allocPrint(allocator, "*(.{s}*)", .{ name_str }),
            },
            .rom_region = region_str,
        });
    } else if (std.mem.eql(u8, arg, "--uram")) {
        const name_str = arg_iter.next() orelse return error.ExpectedSectionName;
        const ram_region_str = arg_iter.next() orelse return error.RamRegionName;
        try sections.append(.{
            .name = name_str,
            .contents = &.{
                try std.fmt.allocPrint(allocator, "*(.{s}*)", .{ name_str }),
            },
            .ram_region = ram_region_str,
        });
    } else if (std.mem.eql(u8, arg, "--zram")) {
        const name_str = arg_iter.next() orelse return error.ExpectedSectionName;
        const ram_region_str = arg_iter.next() orelse return error.RamRegionName;
        try sections.append(.{
            .name = name_str,
            .contents = &.{
                try std.fmt.allocPrint(allocator, "*(.{s}*)", .{ name_str }),
            },
            .ram_region = ram_region_str,
            .init_value = 0,
        });
    } else if (std.mem.eql(u8, arg, "--load")) {
        const name_str = arg_iter.next() orelse return error.ExpectedSectionName;
        const rom_region_str = arg_iter.next() orelse return error.RomRegionName;
        const ram_region_str = arg_iter.next() orelse return error.RamRegionName;
        try sections.append(.{
            .name = name_str,
            .contents = &.{
                try std.fmt.allocPrint(allocator, "*(.{s}*)", .{ name_str }),
            },
            .rom_region = rom_region_str,
            .ram_region = ram_region_str,
        });
    } else if (std.mem.eql(u8, arg, "--section")) {
        const name_str = arg_iter.next() orelse return error.ExpectedSectionName;
        const start_alignment_bytes = arg_iter.next() orelse return error.ExpectedStartAlignment;
        const end_alignment_bytes = arg_iter.next() orelse return error.ExpectedEndAlignment;
        const rom_region_str = arg_iter.next() orelse return error.ExpectedRomRegionName;
        const rom_addr_str = arg_iter.next() orelse return error.ExpectedRomAddress;
        const ram_region_str = arg_iter.next() orelse return error.ExpectedRamRegionName;
        const ram_addr_str = arg_iter.next() orelse return error.ExpectedRamAddress;
        const init_str = arg_iter.next() orelse return error.ExpectedSectionInitValue;
        const contents_length_str = arg_iter.next() orelse return error.ExpectedContentsLength;

        const contents_length = std.fmt.parseInt(usize, contents_length_str, 0) catch return error.InvalidContentsLength;
        const contents: [][]const u8 = try allocator.alloc([]const u8, contents_length);
        for (0..contents_length) |i| {
            contents[i] = arg_iter.next() orelse return error.ExpectedSectionContents;
        }

        var section: Section = .{
            .name = name_str,
            .contents = contents,
            .start_alignment_bytes = null,
            .end_alignment_bytes = null,
        };

        if (start_alignment_bytes.len > 0) section.start_alignment_bytes = std.fmt.parseInt(u32, start_alignment_bytes, 0) catch return error.InvalidSectionStartAlignmentBytes;
        if (end_alignment_bytes.len > 0) section.end_alignment_bytes = std.fmt.parseInt(u32, end_alignment_bytes, 0) catch return error.InvalidSectionEndAlignmentBytes;
        if (rom_region_str.len > 0) section.rom_region = rom_region_str;
        if (ram_region_str.len > 0) section.ram_region = ram_region_str;
        if (rom_addr_str.len > 0) section.rom_address = std.fmt.parseInt(u32, rom_addr_str, 0) catch return error.InvalidSectionRomAddress;
        if (ram_addr_str.len > 0) section.ram_address = std.fmt.parseInt(u32, ram_addr_str, 0) catch return error.InvalidSectionRamAddress;

        if (std.ascii.eqlIgnoreCase(init_str, "skip")) {
            section.skip_init = true;
        } else if (init_str.len > 0) {
            section.init_value = std.fmt.parseInt(u8, init_str, 0) catch return error.InvalidSectionInitValue;
        }

        try sections.append(section);
    } else return false;
    return true;
}

const Chip = @import("Chip.zig");
const Core = @import("Core.zig");
const Memory_Region = @import("Memory_Region.zig");
const Section = @import("Section.zig");
const std = @import("std");
