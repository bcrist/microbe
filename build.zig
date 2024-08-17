pub const Executable_Options = struct {
    name: []const u8,
    root_source_file: ?std.Build.LazyPath = null,
    chip: Chip,
    sections: []const Section,
    enable_runtime_resource_validation: ?bool = null,
    version: ?std.SemanticVersion = null,
    optimize: ?std.builtin.Mode = null,
    max_rss: usize = 0,
    link_libc: ?bool = null,
    pic: ?bool = null,
    strip: ?bool = null,
    unwind_tables: ?bool = null,
    omit_frame_pointer: ?bool = null,
    sanitize_thread: ?bool = null,
    error_tracing: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    zig_lib_dir: ?std.Build.LazyPath = null,
};
pub fn add_executable(b: *std.Build, options: Executable_Options) *std.Build.Step.Compile {
    const optimize = options.optimize orelse b.standardOptimizeOption(.{});
    const enable_runtime_resource_validation = options.enable_runtime_resource_validation orelse switch (optimize) {
        .Debug => true,
        else => false,
    };

    const generate_linkerscript_exe = b.dependencyFromBuildZig(@This(), .{}).artifact("generate_linkerscript");
    const generate_linkerscript = b.addRunArtifact(generate_linkerscript_exe);
    generate_linkerscript.addArg("-o");
    const linkerscript = generate_linkerscript.addOutputFileArg("linkerscript.ld");
    add_chip_and_section_args(generate_linkerscript, options);

    const generate_config_exe = b.dependencyFromBuildZig(@This(), .{}).artifact("generate_config");
    const generate_config = b.addRunArtifact(generate_config_exe);
    generate_config.addArg("-o");
    const config_module_path = generate_config.addOutputFileArg("config.zig");
    add_chip_and_section_args(generate_config, options);
    if (enable_runtime_resource_validation) {
        generate_config.addArg("--runtime-resource-validation");
    }

    // We need to clone the microbe/chip modules because we're going to add the build-specific config import to them.
    // If we didn't clone them you wouldn't be able to compile multiple microbe executables with the same `zig build` invocation.
    const microbe_module = clone_module(b, b.dependencyFromBuildZig(@This(), .{}), "microbe");
    const chip_module = clone_module(b, b.dependency(options.chip.dependency_name, .{}), options.chip.module_name);
    const config_module = b.createModule(.{ .root_source_file = config_module_path });

    config_module.addImport("microbe", microbe_module);
    config_module.addImport("chip", chip_module);

    microbe_module.addImport("chip", chip_module);
    microbe_module.addImport("config", config_module);
    microbe_module.addImport("microbe", microbe_module);

    chip_module.addImport("chip", chip_module);
    chip_module.addImport("config", config_module);
    chip_module.addImport("microbe", microbe_module);

    var exe = b.addExecutable(.{
        .name = options.name,
        .target = b.resolveTargetQuery(options.chip.core.target),
        .root_source_file = options.root_source_file,
        .version = options.version,
        .optimize = optimize,
        .linkage = .static,
        .max_rss = options.max_rss,
        .link_libc = options.link_libc,
        .single_threaded = options.chip.single_threaded,
        .pic = options.pic,
        .strip = options.strip,
        .unwind_tables = options.unwind_tables,
        .omit_frame_pointer = options.omit_frame_pointer,
        .sanitize_thread = options.sanitize_thread,
        .error_tracing = options.error_tracing,
        .use_llvm = options.use_llvm,
        .use_lld = options.use_lld,
        .zig_lib_dir = options.zig_lib_dir,
    });
    exe.bundle_compiler_rt = options.chip.core.bundle_compiler_rt;
    exe.setLinkerScript(linkerscript);
    exe.root_module.addImport("microbe", microbe_module);
    exe.root_module.addImport("config", config_module);
    exe.root_module.addImport("chip", chip_module);

    return exe;
}

pub const Bin_To_UF2_Source = struct {
    path: std.Build.LazyPath,
    base_address: u32 = 0,
    block_size: u9 = 256,
    family: union (enum) {
        rp2040,
        rp2350_arm_nonsecure,
        rp2350_arm_secure,
        rp2350_risc_v,
        rp_absolute,
        rp_data,
        custom: u32,
    },
};
pub fn add_bin_to_uf2(b: *std.Build, basename: []const u8, input_files: []const Bin_To_UF2_Source) std.Build.LazyPath {
    const exe = b.dependencyFromBuildZig(@This(), .{}).artifact("bin_to_uf2");
    const run = b.addRunArtifact(exe);
    run.addArg("-o");
    const output_path = run.addOutputFileArg(basename);
    var last_block_size: usize = 1234;
    var last_family: ?std.meta.FieldType(Bin_To_UF2_Source, .family) = null;
    for (input_files) |f| {
        run.addArg("--family");
        if (f.family != last_family) {
            switch (f.family) {
                .custom => |family| {
                    run.addArg(b.fmt("0x{X}", .{ family }));
                },
                inline else => |family| {
                    run.addArg(@tagName(family));
                },
            }
            last_family = f.family;
        }
        if (f.block_size != last_block_size) {
            run.addArg("--block-size");
            run.addArg(b.fmt("{}", .{ f.block_size }));
            last_block_size = f.block_size;
        }
        if (f.base_address != 0) {
            run.addArg("-a");
            run.addArg(b.fmt("0x{X}", .{ f.base_address }));
        }
        run.addFileArg(f.path);
    }
    return output_path;
}

fn add_chip_and_section_args(run: *std.Build.Step.Run, options: Executable_Options) void {
    run.addArgs(&.{
        "--chip", options.chip.name,
        "-c", options.chip.core.name,
        "--entry", options.chip.entry_point,
    });
    if (!options.chip.single_threaded) run.addArg("--multi-core");
    for (options.chip.extra_config) |extra| {
        run.addArg(if (extra.escape) "--extra-escaped" else "--extra");
        run.addArgs(&.{ extra.name, extra.value });
    }

    for (options.chip.memory_regions) |region| {
        var access_buf: [3]u8 = undefined;
        var access_stream = std.io.fixedBufferStream(&access_buf);
        var access_iter = region.access.iterator();
        while (access_iter.next()) |access| {
            access_stream.writer().writeByte(switch (access) {
                .readable => 'r',
                .writable => 'w',
                .executable => 'x',
            }) catch unreachable;
        }

        run.addArgs(&.{
            "-m",
            region.name,
            run.step.owner.fmt("0x{X}", .{ region.offset }),
            run.step.owner.fmt("0x{X}", .{ region.length }),
            access_stream.getWritten(),
        });
    }

    for (options.sections) |section| {
        if (section.contents.len == 1 and section.is_align4() and section.rom_address == null and section.ram_address == null and section.skip_init == false) {
            if (std.mem.eql(u8, section.contents[0], run.step.owner.fmt("*(.{s}*)", .{ section.name }))) {
                if (section.rom_region) |rom_region| {
                    if (section.init_value == null) {
                        if (section.ram_region) |ram_region| {
                            run.addArgs(&.{ "--load", section.name, rom_region, ram_region });
                        } else {
                            run.addArgs(&.{ "--rom", section.name, rom_region });
                        }
                        continue;
                    }
                } else if (section.ram_region) |ram_region| {
                    if (section.init_value) |init_value| {
                        if (init_value == 0) {
                            run.addArgs(&.{ "--zram", section.name, ram_region });
                            continue;
                        }
                    } else {
                        run.addArgs(&.{ "--uram", section.name, ram_region });
                        continue;
                    }
                }
            } else if (std.mem.eql(u8, section.contents[0], run.step.owner.fmt("KEEP(*(.{s}*))", .{ section.name }))) {
                if (section.ram_region == null and section.init_value == null) {
                    if (section.rom_region) |rom_region| {
                        run.addArgs(&.{ "--keep-rom", section.name, rom_region });
                        continue;
                    }
                }
            }
        }

        run.addArgs(&.{
            "--section",
            section.name,
            fmt_maybe_u32(run.step.owner, section.start_alignment_bytes),
            fmt_maybe_u32(run.step.owner, section.end_alignment_bytes),
            section.rom_region orelse "",
            fmt_maybe_u32(run.step.owner, section.rom_address),
            section.ram_region orelse "",
            fmt_maybe_u32(run.step.owner, section.ram_address),
            if (section.skip_init) "skip" else if (section.init_value) |init| run.step.owner.fmt("{}", .{ init }) else "",
            run.step.owner.fmt("{}", .{ section.contents.len }),
        });
        for (section.contents) |contents| {
            run.addArg(contents);
        }
    }
}

fn fmt_maybe_u32(b: *std.Build, maybe_num: ?u32) []const u8 {
    if (maybe_num) |num| {
        if (num <= 0x100) {
            return b.fmt("{}", .{ num });
        } else {
            return b.fmt("0x{X}", .{ num });
        }
     }
     return "";
}

fn clone_module(dependency: *std.Build.Dependency, module_name: []const u8) *std.Build.Module {
    const module = dependency.module(module_name);
    const clone = module.owner.createModule(.{
        .root_source_file = module.root_source_file,
    });

    var iter = module.import_table.iterator();
    while (iter.next()) |entry| {
        clone.addImport(entry.key_ptr.*, entry.value_ptr.*);
    }

    return clone;
}

pub fn build(b: *std.Build) void {
    _ = b.addModule("microbe", .{ .root_source_file = b.path("src/microbe.zig") });

    _ = b.addExecutable(.{
        .name = "bin_to_uf2",
        .root_source_file = b.path("tools/bin_to_uf2.zig"),
        .target = b.host,
        .optimize = .ReleaseSafe,
    });

    _ = b.addExecutable(.{
        .name = "generate_linkerscript",
        .root_source_file = b.path("tools/generate_linkerscript.zig"),
        .target = b.host,
        .optimize = .ReleaseSafe,
    });

    _ = b.addExecutable(.{
        .name = "generate_config",
        .root_source_file = b.path("tools/generate_config.zig"),
        .target = b.host,
        .optimize = .ReleaseSafe,
    });
}

pub const Core = @import("build/Core.zig");
pub const Chip = @import("build/Chip.zig");
pub const Section = @import("build/Section.zig");
pub const Memory_Region = @import("build/Memory_Region.zig");
const std = @import("std");
