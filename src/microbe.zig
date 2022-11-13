const std = @import("std");
const build_config = @import("build_config.zig");
pub usingnamespace build_config;
const linking = @import("linking.zig");

const LibExeObjStep = std.build.LibExeObjStep;

const Pkg = std.build.Pkg;
const root_path = root() ++ "/";
fn root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}

pub const pkg = Pkg {
    .name = "microbe",
    .source = .{ .path = root_path ++ "runtime/import-package.zig" },
};

pub const EmbeddedExecutable = struct {
    inner: *LibExeObjStep,
    main_packages: std.ArrayList(Pkg),

    pub fn addPackage(exe: *EmbeddedExecutable, package: Pkg) void {
        exe.main_packages.append(package) catch @panic("failed to append");

        for (exe.inner.packages.items) |*entry| {
            if (std.mem.eql(u8, "main", entry.name)) {
                entry.dependencies = exe.main_packages.items;
                break;
            }
        } else @panic("main package not found");
    }

    pub fn addPackagePath(exe: *EmbeddedExecutable, name: []const u8, pkg_index_path: []const u8) void {
        exe.addPackage(Pkg{
            .name = exe.inner.builder.allocator.dupe(u8, name) catch unreachable,
            .source = .{ .path = exe.inner.builder.allocator.dupe(u8, pkg_index_path) catch unreachable },
        });
    }

    pub fn setBuildMode(exe: *EmbeddedExecutable, mode: std.builtin.Mode) void {
        exe.inner.setBuildMode(mode);
    }

    pub fn install(exe: *EmbeddedExecutable) void {
        exe.inner.install();
    }

    pub fn installRaw(exe: *EmbeddedExecutable, dest_filename: []const u8, options: std.build.InstallRawStep.CreateOptions) *std.build.InstallRawStep {
        return exe.inner.installRaw(dest_filename, options);
    }

    pub fn addIncludePath(exe: *EmbeddedExecutable, path: []const u8) void {
        exe.inner.addIncludePath(path);
    }

    pub fn addSystemIncludePath(exe: *EmbeddedExecutable, path: []const u8) void {
        return exe.inner.addSystemIncludePath(path);
    }

    pub fn addCSourceFile(exe: *EmbeddedExecutable, file: []const u8, flags: []const []const u8) void {
        exe.inner.addCSourceFile(file, flags);
    }

    pub fn addOptions(exe: *EmbeddedExecutable, package_name: []const u8, options: *std.build.OptionsStep) void {
        exe.inner.addOptions(package_name, options);
        exe.addPackage(.{ .name = package_name, .source = options.getSource() });
    }

    pub fn addObjectFile(exe: *EmbeddedExecutable, source_file: []const u8) void {
        exe.inner.addObjectFile(source_file);
    }
};

pub fn addEmbeddedExecutable(
    builder: *std.build.Builder,
    name: []const u8,
    source: []const u8,
    chip: build_config.Chip,
    sections: []const build_config.Section,
) EmbeddedExecutable {
    const hash = getHash(chip, sections);

    const config_file_name = std.fmt.allocPrint(builder.allocator, "zig-cache/microbe/config-{s}.zig", .{ &hash }) catch unreachable;
    {
        std.fs.cwd().makeDir(std.fs.path.dirname(config_file_name).?) catch {};
        var config_file = std.fs.cwd().createFile(config_file_name, .{}) catch unreachable;
        defer config_file.close();

        var writer = config_file.writer();

        writer.print("pub const chip_name = .@\"{}\";\n", .{ std.fmt.fmtSliceEscapeUpper(chip.name) }) catch unreachable;
        writer.print("pub const core_name = .@\"{}\";\n", .{ std.fmt.fmtSliceEscapeUpper(chip.core.name) }) catch unreachable;
    }

    const init_file_name = std.fmt.allocPrint(builder.allocator, "zig-cache/microbe/init-{s}.zig", .{ &hash }) catch unreachable;
    {
        std.fs.cwd().makeDir(std.fs.path.dirname(init_file_name).?) catch {};
        var init_file = std.fs.cwd().createFile(init_file_name, .{}) catch unreachable;
        defer init_file.close();

        var writer = init_file.writer();

        var final_sections = builder.allocator.alloc(?usize, chip.memory_regions.len) catch unreachable;
        for (final_sections) |*section_index| {
            section_index.* = null;
        }
        for (sections) |section, i| {
            if (section.ram_region orelse section.rom_region) |region_name| {
                for (chip.memory_regions) |region, r| {
                    if (std.mem.eql(u8, region_name, region.name)) {
                        final_sections[r] = i;
                    }
                }
            }
        }

        writer.writeAll(
            \\const microbe = @import("microbe");
            \\
        ) catch unreachable;

        for (sections) |section, i| {
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
            if (load) writer.print("extern const _{s}_load: anyopaque;\n", .{ section.name }) catch unreachable;
            if (start) writer.print("extern var _{s}_start: anyopaque;\n", .{ section.name }) catch unreachable;
            if (min) writer.print("extern const _{s}_min: anyopaque;\n", .{ section.name }) catch unreachable;
            if (end) writer.print("extern const _{s}_end: anyopaque;\n", .{ section.name }) catch unreachable;
        }

        writer.writeAll(
            \\pub fn init() void {
            \\
        ) catch unreachable;

        for (sections) |section, i| {
            for (final_sections) |section_index| {
                if (section_index == i) {
                    writer.print(
                        \\    if (@ptrToInt(&_{s}_min) > @ptrToInt(&_{s}_end)) microbe.hang();
                        \\
                    , .{ section.name, section.name }) catch unreachable;
                }
            }
            if (section.ram_region) |_| {
                if (section.rom_region) |_| {
                    writer.print(
                        \\    {{
                        \\        const load = @ptrCast([*]const u8, &_{s}_load);
                        \\        const start = @ptrCast([*]u8, &_{s}_start);
                        \\        const end = @ptrCast([*]const u8, &_{s}_end);
                        \\        const len = @ptrToInt(end) - @ptrToInt(start);
                        \\        @memcpy(start, load, len);
                        \\    }}
                        \\
                    , .{ section.name, section.name, section.name }) catch unreachable;
                } else if (section.init_value) |v| {
                    writer.print(
                        \\    {{
                        \\        const start = @ptrCast([*]u8, &_{s}_start);
                        \\        const end = @ptrCast([*]const u8, &_{s}_end);
                        \\        const len = @ptrToInt(end) - @ptrToInt(start);
                        \\        @memset(start, {}, len);
                        \\    }}
                        \\
                    , .{ section.name, section.name, v }) catch unreachable;
                }
            }
        }

        writer.writeAll(
            \\}
            \\
            \\
        ) catch unreachable;
    }

    const config_pkg = Pkg {
        .name = "config",
        .source = .{ .path = config_file_name },
    };

    const init_pkg = Pkg {
        .name = "init",
        .source = .{ .path = init_file_name },
        .dependencies = &.{ pkg },
    };

    const chip_pkg = Pkg {
        .name = "chip",
        .source = .{ .path = chip.path },
        .dependencies = &.{ pkg },
    };

    const core_pkg = Pkg {
        .name = "core",
        .source = .{ .path = chip.core.path },
        .dependencies = &.{ pkg },
    };

    var exe = EmbeddedExecutable{
        .inner = builder.addExecutable(name, root_path ++ "runtime/microbe.zig"),
        .main_packages = std.ArrayList(Pkg).init(builder.allocator),
    };

    //exe.inner.use_stage1 = true;

    exe.inner.single_threaded = chip.single_threaded;
    exe.inner.setTarget(chip.core.target);

    const linkerscript = linking.LinkerScriptStep.create(builder, chip, sections, &hash) catch unreachable;
    exe.inner.setLinkerScriptPath(.{ .generated = &linkerscript.generated_file });

    // TODO:
    // - Generate the linker scripts from the "chip" or "board" package instead of using hardcoded ones.
    //   - This requires building another tool that runs on the host that compiles those files and emits the linker script.
    //    - src/tools/linkerscript-gen.zig is the source file for this
    exe.inner.bundle_compiler_rt = (exe.inner.target.cpu_arch.? != .avr); // don't bundle compiler_rt for AVR as it doesn't compile right now

    // these packages will be re-exported from runtime/microbe.zig
    exe.inner.addPackage(chip_pkg);
    exe.inner.addPackage(core_pkg);
    exe.inner.addPackage(config_pkg);
    exe.inner.addPackage(init_pkg);
    exe.inner.addPackage(.{
        .name = "main",
        .source = .{ .path = source },
    });
    exe.addPackage(pkg);

    return exe;
}

fn getHash(chip: build_config.Chip, sections: []const build_config.Section) [32]u8 {
    var hasher = std.hash.SipHash128(1, 2).init("abcdefhijklmnopq");

    hasher.update(chip.name);
    hasher.update(chip.path);
    hasher.update(chip.core.name);
    hasher.update(chip.core.path);

    for (sections) |section| {
        hasher.update(section.name);
        for (section.contents) |entry| {
            hasher.update(entry);
        }
        hasher.update(std.mem.asBytes(&section.start_alignment_bytes));
        hasher.update(std.mem.asBytes(&section.end_alignment_bytes));
        if (section.rom_region) |region| {
            hasher.update(region);
        } else {
            hasher.update("~");
        }
        if (section.ram_region) |region| {
            hasher.update(region);
        } else {
            hasher.update("~");
        }
        if (section.init_value) |v| {
            hasher.update(std.mem.asBytes(&v));
        } else {
            hasher.update("~");
        }
    }

    var raw: [16]u8 = undefined;
    hasher.final(&raw);

    var hex: [32]u8 = undefined;
    _ = std.fmt.bufPrint(&hex, "{}", .{ std.fmt.fmtSliceHexLower(&raw) }) catch unreachable;
    return hex;
}
