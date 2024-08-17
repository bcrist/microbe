pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var output_path: []const u8 = "config.zig";
    var runtime_resource_validation = false;

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
    while (arg_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            output_path = arg_iter.next() orelse return error.ExpectedOutputPath;
        } else if (std.mem.eql(u8, arg, "--runtime-resource-validation")) {
            runtime_resource_validation = true;
        } else if (!(try args.try_chip_args(allocator, &arg_iter, arg, &chip)) and !(try args.try_section(allocator, &arg_iter, arg, &sections))) {
            try std.io.getStdErr().writer().print("Unrecognized argument: {s}", .{ arg });
            return error.InvalidArgument;
        }
    }

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    const writer = out_file.writer();
    try make(allocator, chip, sections.items, runtime_resource_validation, writer.any());
}

fn make(allocator: std.mem.Allocator, chip: Chip, sections: []const Section, runtime_resource_validation: bool, writer: std.io.AnyWriter) !void {
    try writer.writeAll(
        \\const std = @import("std");
        \\const chip = @import("chip");
        \\
        \\
    );

    // TODO consider putting git commit hash in here
    try writer.print(
        \\pub const chip_name = "{}";
        \\pub const core_name = "{}";
        \\
        \\pub const target = "{s}";
        \\
        \\pub const runtime_resource_validation = {};
        \\
    , .{
        std.fmt.fmtSliceEscapeUpper(chip.name),
        std.fmt.fmtSliceEscapeUpper(chip.core.name),
        std.fmt.fmtSliceEscapeUpper(try std.zig.CrossTarget.zigTriple(chip.core.target, allocator)),
        runtime_resource_validation,
    });

    try writer.writeAll(
        \\
        \\comptime {
        \\    if (!std.mem.startsWith(u8, chip_name, chip.base_name)) {
        \\        @compileError("Chip module's name does not match root configuration!");
        \\    }
        \\
        \\    if (!std.mem.eql(u8, core_name, chip.core_name)) {
        \\        @compileError("Core module's name does not match root configuration!");
        \\    }
        \\}
        \\
        \\
    );

    for (chip.extra_config) |option| {
        if (option.escape) {
            try writer.print("pub const {} = \"{s}\";\n", .{ std.zig.fmtId(option.name), std.fmt.fmtSliceEscapeUpper(option.value) });
        } else {
            try writer.print("pub const {} = {s};\n", .{ std.zig.fmtId(option.name), option.value });
        }
    }

    try writer.writeAll("\npub const regions = struct {\n");
    for (chip.memory_regions) |region| {
        try writer.print("    pub const {} = mem_slice(0x{X}, 0x{X});\n", .{ std.zig.fmtId(region.name), region.offset, region.length });
    }
    try writer.writeAll(
        \\};
        \\
    );

    var final_sections = try allocator.alloc(?usize, chip.memory_regions.len);
    @memset(final_sections, null);
    for (sections, 0..) |section, i| {
        if (section.ram_region orelse section.rom_region) |region_name| {
            for (chip.memory_regions, 0..) |region, r| {
                if (std.mem.eql(u8, region_name, region.name)) {
                    final_sections[r] = i;
                }
            }
        }
    }

    for (sections, 0..) |section, i| {
        var load = false;
        var start = false;
        var min = false;
        var end = false;
        for (final_sections) |section_index| {
            if (section_index == i) {
                min = true;
                end = true;
            }
        }
        if (section.ram_region) |_| {
            if (section.rom_region) |_| {
                load = true;
                start = true;
                end = true;
            } else if (section.init_value) |_| {
                start = true;
                end = true;
            }
        }
        if (load) try writer.print("extern const _{s}_load: anyopaque;\n", .{ section.name });
        if (start) try writer.print("extern var _{s}_start: anyopaque;\n", .{ section.name });
        if (min) try writer.print("extern const _{s}_min: anyopaque;\n", .{ section.name });
        if (end) try writer.print("extern const _{s}_end: anyopaque;\n", .{ section.name });
    }

    try writer.writeAll(
        \\
        \\pub fn init_ram() callconv(.C) void {
        \\    @setCold(true);
        \\
    );

    for (sections) |section| {
        if (section.skip_init) continue;

        if (section.ram_region) |_| {
            if (section.rom_region) |_| {
                try writer.print(
                    \\    {{
                    \\        const load: [*]const u8 = @ptrCast(&_{s}_load);
                    \\        const start: [*]u8 = @ptrCast(&_{s}_start);
                    \\        const end: [*]const u8 = @ptrCast(&_{s}_end);
                    \\        const len = @intFromPtr(end) - @intFromPtr(start);
                    \\        @memcpy(start[0..len], load);
                    \\    }}
                    \\
                , .{ section.name, section.name, section.name });
            } else if (section.init_value) |v| {
                try writer.print(
                    \\    {{
                    \\        const start: [*]u8 = @ptrCast(&_{s}_start);
                    \\        const end: [*]const u8 = @ptrCast(&_{s}_end);
                    \\        const len = @intFromPtr(end) - @intFromPtr(start);
                    \\        @memset(start[0..len], {});
                    \\    }}
                    \\
                , .{ section.name, section.name, v });
            }
        }
    }

    try writer.writeAll(
        \\}
        \\
        \\
    );

    try writer.writeAll(
        \\fn mem_slice(comptime begin: u32, comptime len: u32) []u8 {
        \\    var slice: []u8 = undefined;
        \\    slice.ptr = @ptrFromInt(begin);
        \\    slice.len = len;
        \\    return slice;
        \\}
        \\
    );
}

const Chip = @import("Chip.zig");
const Core = @import("Core.zig");
const Section = @import("Section.zig");
const args = @import("args.zig");
const std = @import("std");
