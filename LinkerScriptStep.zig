const std = @import("std");
const Section = @import("Section.zig");
const Chip = @import("Chip.zig");
const hash = @import("hash.zig");
const Step = std.build.Step;
const Build = std.Build;
const GeneratedFile = std.build.GeneratedFile;

const LinkerScriptStep = @This();

step: Step,
output_file: std.build.GeneratedFile,
chip: Chip,
sections: []Section,

pub fn create(owner: *Build, chip: Chip, sections: []const Section) *LinkerScriptStep {
    var self = owner.allocator.create(LinkerScriptStep) catch @panic("OOM");
    self.* = LinkerScriptStep{
        .step = Step.init(.{
            .id = .custom,
            .name = "linkerscript",
            .owner = owner,
            .makeFn = make,
        }),
        .output_file = .{
            .step = &self.step,
        },
        .chip = chip,
        .sections = owner.allocator.dupe(Section, sections) catch @panic("OOM"),
    };
    return self;
}

pub fn getOutputSource(self: *const LinkerScriptStep) std.Build.LazyPath {
    return .{ .generated = &self.output_file };
}

fn findMemoryRegionIndex(region_name: []const u8, chip: Chip) !usize {
    for (chip.memory_regions, 0..) |region, i| {
        if (std.mem.eql(u8, region_name, region.name)) {
            return i;
        }
    }
    std.log.err("chip {s} does not have a memory region named {any}", .{ chip.name, region_name });
    return error.MissingMemoryRegion;
}

fn make(step: *Step, progress: *std.Progress.Node) !void {
    _ = progress;

    const b = step.owner;
    const self = @fieldParentPtr(LinkerScriptStep, "step", step);
    const chip = self.chip;
    const target = chip.core.target;

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make hash unique. Change this if linker script implementation is modified.
    man.hash.add(@as(u32, 0x0123_4567));

    hash.addChipAndSections(&man.hash, chip, self.sections);

    if (try step.cacheHit(&man)) {
        // Cache hit, skip subprocess execution.
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{
            "microbe",
            &digest,
            "link.ld",
        });
        return;
    }

    const digest = man.final();
    self.output_file.path = try b.cache_root.join(b.allocator, &.{
        "microbe",
        &digest,
        "link.ld",
    });
    const cache_dir = "microbe" ++ std.fs.path.sep_str ++ digest;
    b.cache_root.handle.makePath(cache_dir) catch |err| {
        return step.fail("unable to make path {s}: {s}", .{ cache_dir, @errorName(err) });
    };

    if (target.cpu_arch == null) {
        std.log.err("target does not have 'cpu_arch'", .{});
        return error.NoCpuArch;
    }

    var contents = std.ArrayList(u8).init(b.allocator);
    defer contents.deinit();

    const writer = contents.writer();

    try writer.print(
        \\/*
        \\ * This file was auto-generated by microbe
        \\ *
        \\ * Target CPU:  {s}
        \\ * Target Chip: {s}
        \\ */
        \\ENTRY(_start);
        \\
        \\MEMORY
        \\{{
        \\
    , .{ chip.core.name, chip.name });

    for (chip.memory_regions) |region| {
        try writer.print("  {s} (", .{ region.name });
        if (region.access.contains(.readable)) try writer.writeAll("r");
        if (region.access.contains(.writable)) try writer.writeAll("w");
        if (region.access.contains(.executable)) try writer.writeAll("x");
        try writer.print(") : ORIGIN = 0x{X:0>8}, LENGTH = 0x{X:0>8}\n", .{ region.offset, region.length });
    }

    var final_sections = try b.allocator.alloc(?usize, chip.memory_regions.len);
    @memset(final_sections, null);

    for (self.sections, 0..) |section, i| {
        if (section.ram_region) |ram| {
            var r = try findMemoryRegionIndex(ram, chip);
            final_sections[r] = i;
            if (section.rom_region) |rom| {
                // just make sure the rom region exists
                _ = try findMemoryRegionIndex(rom, chip);
            }
        } else if (section.rom_region) |rom| {
            var r = try findMemoryRegionIndex(rom, chip);
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

    for (self.sections, 0..) |section, section_index| {
        if (section.ram_region) |ram| {
            const r = try findMemoryRegionIndex(ram, chip);
            const is_final_section = final_sections[r] == section_index;
            if (section.rom_region) |rom| {
                try writeSectionLoad(writer, section, is_final_section, ram, rom);
            } else {
                try writeSectionRam(writer, section, is_final_section, ram);
            }
        } else if (section.rom_region) |rom| {
            const r = try findMemoryRegionIndex(rom, chip);
            const is_final_section = final_sections[r] == section_index;
            try writeSectionRom(writer, section, is_final_section, rom);
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
            var section = self.sections[section_index];
            try writer.print(
                \\_{s}_end = ORIGIN({s}) + LENGTH({s});
                \\
            , .{ section.name, region.name, region.name });
        }
    }

    var file = try b.cache_root.handle.createFile(self.output_file.getPath(), .{});
    defer file.close();

    try file.writeAll(contents.items);
    try man.writeManifest();
}

fn writeSectionRam(writer: anytype, section: Section, is_final_section: bool, region_name: []const u8) !void {
    try writer.print(
        \\  .{s} (NOLOAD) :
        \\  {{
        \\
    , .{ section.name });
    try writeSectionContents(writer, section, is_final_section);
    try writer.print(
        \\  }} > {s}
        \\
        \\
    , .{ region_name });
}

fn writeSectionRom(writer: anytype, section: Section, is_final_section: bool, region_name: []const u8) !void {
    try writer.print(
        \\  .{s} :
        \\  {{
        \\
    , .{ section.name });
    try writeSectionContents(writer, section, is_final_section);
    try writer.print(
        \\  }} > {s}
        \\
        \\
    , .{ region_name });
}

fn writeSectionLoad(writer: anytype, section: Section, is_final_section: bool, ram_region: []const u8, rom_region: []const u8) !void {
    try writer.print(
        \\  .{s} :
        \\  {{
        \\
    , .{ section.name });
    try writeSectionContents(writer, section, is_final_section);
    try writer.print(
        \\  }} > {s} AT > {s}
        \\  _{s}_load = LOADADDR(.{s});
        \\
        \\
    , .{ ram_region, rom_region, section.name, section.name });
}

fn writeSectionContents(writer: anytype, section: Section, is_final_section: bool) !void {
    var buf: [64]u8 = undefined;
    var clean_name = try std.fmt.bufPrint(&buf, "{s}", .{ section.name });
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