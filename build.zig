pub fn build(b: *std.Build) void {
    _ = b.addModule("microbe", .{ .root_source_file = .{ .path = "src/microbe.zig" } });
}

pub fn add_bin_to_uf2(b: *std.Build, input_file: std.Build.LazyPath, options: Bin_To_UF2_Step.Options) *Bin_To_UF2_Step {
    return Bin_To_UF2_Step.create(b, input_file, options);
}

pub fn addExecutable(b: *std.Build, options: Executable_Options) *std.Build.Step.Compile {
    const optimize = options.optimize orelse b.standardOptimizeOption(.{});
    const enable_runtime_resource_validation = options.enable_runtime_resource_validation orelse switch (optimize) {
        .Debug => true,
        else => false,
    };

    const config_step = Config_Step.create(b, options.chip, options.sections, enable_runtime_resource_validation);
    const linkerscript_step = Linker_Script_Step.create(b, options.chip, options.sections);

    const microbe_module = clone_module(b, "microbe", "microbe");
    const chip_module = clone_module(b, options.chip.dependency_name, options.chip.module_name);
    const config_module = b.createModule(.{ .root_source_file = config_step.get_output() });

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
        .target = options.chip.core.target,
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
    exe.setLinkerScriptPath(linkerscript_step.get_output());
    exe.root_module.addImport("microbe", microbe_module);
    exe.root_module.addImport("config", config_module);
    exe.root_module.addImport("chip", chip_module);

    return exe;
}

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

fn clone_module(b: *std.Build, dependency_name: []const u8, module_name: []const u8) *std.Build.Module {
    const module = b.dependency(dependency_name, .{}).module(module_name);
    const clone = module.owner.createModule(.{
        .root_source_file = module.root_source_file
    });

    var iter = module.import_table.iterator();
    while (iter.next()) |entry| {
        clone.addImport(entry.key_ptr.*, entry.value_ptr.*) catch @panic("OOM");
    }

    return clone;
}

pub const Core = @import("Core.zig");
pub const Chip = @import("Chip.zig");
pub const Section = @import("Section.zig");
pub const Memory_Region = @import("Memory_Region.zig");
pub const Bin_To_UF2_Step = @import("Bin_To_UF2_Step.zig");
pub const Config_Step = @import("Config_Step.zig");
pub const Linker_Script_Step = @import("Linker_Script_Step.zig");
const std = @import("std");
