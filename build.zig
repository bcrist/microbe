pub const Executable_Options = struct {
    name: []const u8,
    root_module: *std.Build.Module,
    chip: Chip,
    sections: []const Section,
    runtime_resource_validation: ?bool = null,
    breakpoint_on_panic: ?bool = null,
    version: ?std.SemanticVersion = null,
    max_rss: usize = 0,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    zig_lib_dir: ?std.Build.LazyPath = null,
};

pub fn add_executable(b: *std.Build, options: Executable_Options) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(options.chip.core.target);
    const optimize = options.root_module.optimize orelse b.standardOptimizeOption(.{});
    const is_debug = optimize == .Debug;

    const microbe_dep = b.dependencyFromBuildZig(@This(), .{});

    const generate_linkerscript_exe = microbe_dep.artifact("generate_linkerscript");
    const generate_linkerscript = b.addRunArtifact(generate_linkerscript_exe);
    generate_linkerscript.addArg("-o");
    const linkerscript = generate_linkerscript.addOutputFileArg("linkerscript.ld");
    add_chip_and_section_args(generate_linkerscript, options);

    const generate_config_exe = microbe_dep.artifact("generate_config");
    const generate_config = b.addRunArtifact(generate_config_exe);
    generate_config.addArg("-o");
    const config_module_path = generate_config.addOutputFileArg("config.zig");
    add_chip_and_section_args(generate_config, options);
    if (options.runtime_resource_validation orelse is_debug) {
        generate_config.addArg("--runtime-resource-validation");
    }
    if (options.breakpoint_on_panic orelse is_debug) {
        generate_config.addArg("--breakpoint-on-panic");
    }

    // We need to clone the microbe/chip modules because we're going to add the build-specific config import to them.
    // If we didn't clone them you wouldn't be able to compile multiple microbe executables with the same `zig build` invocation.
    const microbe_module = clone_module(microbe_dep.module("microbe"), target, optimize);
    const internal_module = clone_module(microbe_dep.module("microbe_internal"), target, optimize);
    const chip_module = clone_module(b.dependency(options.chip.dependency_name, .{}).module(options.chip.module_name), target, optimize);
    const root_module = clone_module(options.root_module, target, optimize);
    const config_module = b.createModule(.{
        .root_source_file = config_module_path,
        .optimize = optimize,
        .target = target,
    });

    config_module.addImport("microbe", microbe_module);
    config_module.addImport("chip", chip_module);

    microbe_module.addImport("chip", chip_module);
    microbe_module.addImport("config", config_module);
    microbe_module.addImport("microbe", microbe_module);
    microbe_module.addImport("microbe_internal", internal_module);

    internal_module.addImport("chip", chip_module);

    var replacement_modules = std.StringHashMap(*std.Build.Module).init(b.allocator);
    replacement_modules.put("microbe", microbe_module) catch @panic("OOM");
    replacement_modules.put("microbe_internal", internal_module) catch @panic("OOM");
    replacement_modules.put("config", config_module) catch @panic("OOM");
    replacement_modules.put("chip", chip_module) catch @panic("OOM");

    replace_imports(chip_module, &replacement_modules);
    replace_imports(root_module, &replacement_modules);

    var exe = b.addExecutable(.{
        .name = options.name,
        .root_module = root_module,
        .version = options.version,
        .linkage = .static,
        .max_rss = options.max_rss,
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

pub const UF2_Family = union (enum) {
    rp2040,
    rp2350_arm_nonsecure,
    rp2350_arm_secure,
    rp2350_risc_v,
    rp_absolute,
    rp_data,
    custom: u32,
};
pub const Bin_To_UF2_Source = struct {
    path: std.Build.LazyPath,
    base_address: u32 = 0,
    block_size: u9 = 256,
    family: UF2_Family,
};
pub fn add_bin_to_uf2(b: *std.Build, basename: []const u8, input_files: []const Bin_To_UF2_Source) std.Build.LazyPath {
    const exe = b.dependencyFromBuildZig(@This(), .{}).artifact("bin_to_uf2");
    const run = b.addRunArtifact(exe);
    run.addArg("-o");
    const output_path = run.addOutputFileArg(basename);
    var last_block_size: usize = 1234;
    var last_family: ?UF2_Family = null;
    for (input_files) |f| {
        if (!std.meta.eql(last_family, f.family)) {
            run.addArg("--family");
            switch (f.family) {
                .custom => |family| {
                    run.addArg(b.fmt("0x{X}", .{ family }));
                },
                inline else => |_, family| {
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

pub fn add_chip_and_section_args(run: *std.Build.Step.Run, options: Executable_Options) void {
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

pub fn clone_module(module: *std.Build.Module, target: ?std.Build.ResolvedTarget, optimize: ?std.builtin.OptimizeMode) *std.Build.Module {
    const clone = module.owner.createModule(.{
        .root_source_file = module.root_source_file,
        .optimize = optimize orelse module.optimize,
        .target = target orelse module.resolved_target,
        .link_libc = module.link_libc,
        .link_libcpp = module.link_libcpp,
        .single_threaded = module.single_threaded,
        .strip = module.strip,
        .unwind_tables = module.unwind_tables,
        .dwarf_format = module.dwarf_format,
        .code_model = module.code_model,
        .stack_protector = module.stack_protector,
        .stack_check = module.stack_check,
        .sanitize_c = module.sanitize_c,
        .sanitize_thread = module.sanitize_thread,
        .fuzz = module.fuzz,
        .valgrind = module.valgrind,
        .pic = module.pic,
        .red_zone = module.red_zone,
        .omit_frame_pointer = module.omit_frame_pointer,
        .error_tracing = module.error_tracing,
        .no_builtin = module.no_builtin,
    });

    var import_iter = module.import_table.iterator();
    while (import_iter.next()) |entry| {
        clone.addImport(entry.key_ptr.*, entry.value_ptr.*);
    }

    var framework_iter = module.frameworks.iterator();
    while (framework_iter.next()) |entry| {
        clone.linkFramework(entry.key_ptr.*, entry.value_ptr.*);
    }

    const alloc = module.owner.allocator;

    clone.c_macros.appendSlice(alloc, module.c_macros.items) catch @panic("OOM");
    clone.include_dirs.appendSlice(alloc, module.include_dirs.items) catch @panic("OOM");
    clone.lib_paths.appendSlice(alloc, module.lib_paths.items) catch @panic("OOM");
    clone.rpaths.appendSlice(alloc, module.rpaths.items) catch @panic("OOM");
    clone.link_objects.appendSlice(alloc, module.link_objects.items) catch @panic("OOM");

    return clone;
}

pub fn replace_imports(module: *std.Build.Module, replacements: *std.StringHashMap(*std.Build.Module)) void {
    var chip_imports_iter = module.import_table.iterator();
    while (chip_imports_iter.next()) |entry| {
        const gop = replacements.getOrPut(entry.key_ptr.*) catch unreachable;
        if (gop.found_existing) {
            entry.value_ptr.* = gop.value_ptr.*;
        } else {
            const cloned = clone_module(entry.value_ptr.*, module.resolved_target, module.optimize);
            gop.key_ptr.* = entry.key_ptr.*;
            gop.value_ptr.* = cloned;
            replace_imports(cloned, replacements);
        }
    }
}

pub fn build(b: *std.Build) void {
    const internal = b.addModule("microbe_internal", .{ .root_source_file = b.path("src/internal.zig") });
    const chip_template = b.createModule(.{ .root_source_file = b.path("template/chip.zig") });
    const microbe = b.addModule("microbe", .{
        .root_source_file = b.path("src/microbe.zig"),
        .imports = &.{
            .{ .name = "chip", .module = chip_template },
            .{ .name = "microbe_internal", .module = internal },
        },
    });
    internal.addImport("microbe", microbe);
    chip_template.addImport("microbe", microbe);
    chip_template.addImport("microbe_internal", internal);

    b.installArtifact(b.addExecutable(.{
        .name = "bin_to_uf2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/bin_to_uf2.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    }));

    b.installArtifact(b.addExecutable(.{
        .name = "generate_linkerscript",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/generate_linkerscript.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    }));

    b.installArtifact(b.addExecutable(.{
        .name = "generate_config",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/generate_config.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    }));
}

pub const Core = @import("build/Core.zig");
pub const Chip = @import("build/Chip.zig");
pub const Section = @import("build/Section.zig");
pub const Memory_Region = @import("build/Memory_Region.zig");
const std = @import("std");
