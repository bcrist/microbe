pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var output_path: []const u8 = "linkerscript.ld";

    var chip: Chip = .{
        .name = "",
        .dependency_name = "",
        .module_name = "",
        .core = Core.cortex_m0,
        .memory_regions = &.{},
    };

    var sections = std.ArrayList(Section).init(allocator);
    defer sections.deinit();

    var arg_iter = try std.process.argsWithAllocator(allocator);
    defer arg_iter.deinit();
    _ = arg_iter.next(); // exe name
    while (arg_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            output_path = arg_iter.next() orelse return error.ExpectedOutputPath;
        } else if (!(try args.try_chip_args(allocator, &arg_iter, arg, &chip)) and !(try args.try_section(allocator, &arg_iter, arg, &sections))) {
            try std.io.getStdErr().writer().print("Unrecognized argument: {s}", .{ arg });
            return error.InvalidArgument;
        }
    }

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    const writer = out_file.writer();
    try make(allocator, chip, sections.items, writer.any());
}

fn make(temp: std.mem.Allocator, chip: Chip, sections: []const Section, writer: std.io.AnyWriter) !void {
    try writer.print(
        \\ENTRY({s});
        \\
        \\MEMORY
        \\{{
        \\
    , .{ chip.entry_point });

    for (chip.memory_regions) |region| {
        try writer.print("  {s} (", .{ region.name });
        if (region.access.contains(.readable)) try writer.writeAll("r");
        if (region.access.contains(.writable)) try writer.writeAll("w");
        if (region.access.contains(.executable)) try writer.writeAll("x");
        try writer.print(") : ORIGIN = 0x{X:0>8}, LENGTH = 0x{X:0>8}\n", .{ region.offset, region.length });
    }

    var final_sections = try temp.alloc(?usize, chip.memory_regions.len);
    defer temp.free(final_sections);
    @memset(final_sections, null);

    for (sections, 0..) |section, i| {
        if (section.ram_region) |ram| {
            const r = try find_memory_region_index(ram, chip);
            final_sections[r] = i;
            if (section.rom_region) |rom| {
                // just make sure the rom region exists
                _ = try find_memory_region_index(rom, chip);
            } else if (section.rom_address) |addr| {
                // just make sure the rom region exists
                _ = try find_memory_region_index_by_address(addr, chip);
            }
        } else if (section.ram_address) |ram_addr| {
            const r = try find_memory_region_index_by_address(ram_addr, chip);
            final_sections[r] = i;
            if (section.rom_region) |rom| {
                // just make sure the rom region exists
                _ = try find_memory_region_index(rom, chip);
            } else if (section.rom_address) |addr| {
                // just make sure the rom region exists
                _ = try find_memory_region_index_by_address(addr, chip);
            }
        } else if (section.rom_region) |rom| {
            const r = try find_memory_region_index(rom, chip);
            final_sections[r] = i;
        } else if (section.rom_address) |rom_addr| {
            const r = try find_memory_region_index_by_address(rom_addr, chip);
            final_sections[r] = i;
        }
    }

    try writer.writeAll(
        \\}
        \\
        \\SECTIONS
        \\{
        \\
    );

    for (sections, 0..) |section, section_index| {
        const has_rom_assignment = section.rom_region != null or section.rom_address != null;
        const has_ram_assignment = section.ram_region != null or section.ram_address != null;

        if (has_ram_assignment) {
            const r = if (section.ram_region) |region| try find_memory_region_index(region, chip) else try find_memory_region_index_by_address(section.ram_address.?, chip);
            const is_final_section = final_sections[r] == section_index;
            if (has_rom_assignment) {
                try write_section_load(writer, section, is_final_section);
            } else {
                try write_section_ram(writer, section, is_final_section);
            }
        } else if (has_rom_assignment) {
            const r = if (section.rom_region) |region| try find_memory_region_index(region, chip) else try find_memory_region_index_by_address(section.rom_address.?, chip);
            const is_final_section = final_sections[r] == section_index;
            try write_section_rom(writer, section, is_final_section);
        } else {
            std.log.err("Section {s} must be assigned to a ROM or RAM memory range, or both!", .{ section.name });
            return error.InvalidSection;
        }
    }

    try writer.writeAll(
        \\}
        \\
    );

    for (chip.memory_regions, 0..) |region, region_index| {
        if (final_sections[region_index]) |section_index| {
            const section = sections[section_index];
            try writer.print(
                \\_{s}_end = ORIGIN({s}) + LENGTH({s});
                \\
            , .{ section.name, region.name, region.name });
        }
    }
}

fn write_section_ram(writer: anytype, section: Section, is_final_section: bool) !void {
    try writer.print("  .{s}", .{ section.name });
    if (section.ram_address) |addr| {
        try writer.print(" 0x{X}", .{ addr });
    }
    try writer.writeAll(" (NOLOAD) : {\n");
    try write_section_contents(writer, section, is_final_section);
    try writer.writeAll("  }");
    if (section.ram_region) |region| {
        try writer.print(" > {s}", .{ region });
    }
    try writer.writeAll("\n\n");
}

fn write_section_rom(writer: anytype, section: Section, is_final_section: bool) !void {
    try writer.print("  .{s}", .{ section.name });
    if (section.rom_address) |addr| {
        try writer.print(" 0x{X}", .{ addr });
    }
    try writer.writeAll(" : {\n");
    try write_section_contents(writer, section, is_final_section);
    try writer.writeAll("  }");
    if (section.rom_region) |region| {
        try writer.print(" > {s}", .{ region });
    }
    try writer.writeAll("\n\n");
}

fn write_section_load(writer: anytype, section: Section, is_final_section: bool) !void {
    try writer.print("  .{s}", .{ section.name });
    if (section.ram_address) |addr| {
        try writer.print(" 0x{X}", .{ addr });
    }
    try writer.writeAll(" :");
    if (section.rom_address) |addr| {
        try writer.print(" AT(0x{X})", .{ addr });
    }
    try writer.writeAll(" {\n");
    try write_section_contents(writer, section, is_final_section);
    try writer.writeAll(" }");
    if (section.ram_region) |region| {
        try writer.print(" > {s}", .{ region });
    }
    if (section.rom_region) |region| {
        try writer.print(" AT > {s}", .{ region });
    }
    try writer.print(
        \\
        \\  _{s}_load = LOADADDR(.{s});
        \\
        \\
    , .{ section.name, section.name });
}

fn write_section_contents(writer: anytype, section: Section, is_final_section: bool) !void {
    var buf: [64]u8 = undefined;
    const clean_name = try std.fmt.bufPrint(&buf, "{s}", .{ section.name });
    for (clean_name) |*c| {
        switch (c.*) {
            'a'...'z', 'A'...'Z', '0'...'9' => {},
            else => {
                c.* = '_';
            },
        }
    }
    if (section.start_alignment_bytes) |alignment| {
        try writer.print(
            \\    . = ALIGN({});
            \\
        , .{ alignment });
    }
    try writer.print(
        \\    _{s}_start = .;
        \\
    , .{ clean_name });
    for (section.contents) |entry| {
        try writer.print(
            \\    {s}
            \\
        , .{ entry });
    }
    if (section.end_alignment_bytes) |alignment| {
        try writer.print(
            \\    . = ALIGN({});
            \\
        , .{ alignment });
    }
    if (is_final_section) {
        try writer.print(
            \\    _{s}_min = .;
            \\
        , .{ clean_name });
    } else {
        try writer.print(
            \\    _{s}_end = .;
            \\
        , .{ clean_name });
    }
}

fn find_memory_region_index(region_name: []const u8, chip: Chip) !usize {
    for (chip.memory_regions, 0..) |region, i| {
        if (std.mem.eql(u8, region_name, region.name)) {
            return i;
        }
    }
    std.log.err("chip {s} does not have a memory region named {any}", .{ chip.name, region_name });
    return error.MissingMemoryRegion;
}

fn find_memory_region_index_by_address(address: u32, chip: Chip) !usize {
    for (chip.memory_regions, 0..) |region, i| {
        if (address >= region.offset and address < region.offset + region.length) {
            return i;
        }
    }
    std.log.err("chip {s} does not have a memory region containing address 0x{X}", .{ chip.name, address });
    return error.MissingMemoryRegion;
}

const Chip = @import("Chip.zig");
const Core = @import("Core.zig");
const Section = @import("Section.zig");
const args = @import("args.zig");
const std = @import("std");
