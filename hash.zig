pub fn add_chip_and_sections(hash: *std.Build.Cache.HashHelper, chip: Chip, sections: []const Section) void {
    hash.addBytes(chip.name);
    hash.addBytes(chip.core.name);

    for (chip.memory_regions) |memory_region| {
        hash.addBytes(memory_region.name);
        hash.add(memory_region.offset);
        hash.add(memory_region.length);
        hash.add(memory_region.access.bits.mask);
    }

    for (chip.extra_config) |option| {
        hash.addBytes(option.name);
        hash.add(option.escape);
        hash.addBytes(option.value);
    }

    for (sections) |section| {
        hash.addBytes(section.name);
        for (section.contents) |entry| {
            hash.addBytes(entry);
        }
        hash.addBytes(std.mem.asBytes(&section.start_alignment_bytes));
        hash.addBytes(std.mem.asBytes(&section.end_alignment_bytes));
        hash.addBytes(section.rom_region orelse "~");
        hash.addBytes(section.ram_region orelse "~");
        hash.addBytes(if (section.init_value) |v| std.mem.asBytes(&v) else "~");
    }
}

const Chip = @import("Chip.zig");
const Section = @import("Section.zig");
const std = @import("std");
