const std = @import("std");
pub const Core = @import("Core.zig");
pub const Chip = @import("Chip.zig");
pub const Section = @import("Section.zig");
pub const MemoryRegion = @import("MemoryRegion.zig");
pub const BinToUf2Step = @import("BinToUf2Step.zig");
pub const ConfigStep = @import("ConfigStep.zig");
pub const LinkerScriptStep = @import("LinkerScriptStep.zig");

pub const ExecutableOptions = struct {
    name: []const u8,
    root_source_file: ?std.Build.LazyPath = null,
    chip: Chip,
    sections: []const Section,
    enable_runtime_resource_validation: ?bool = null,
    version: ?std.SemanticVersion = null,
    optimize: ?std.builtin.Mode = null,
    max_rss: usize = 0,
    link_libc: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
};

pub fn addExecutable(b: *std.Build, options: ExecutableOptions) *std.Build.Step.Compile {
    const optimize = options.optimize orelse b.standardOptimizeOption(.{});
    const enable_runtime_resource_validation = options.enable_runtime_resource_validation orelse switch (optimize) {
        .Debug => true,
        else => false,
    };

    const config_step = ConfigStep.create(b, options.chip, options.sections, enable_runtime_resource_validation);
    const linkerscript_step = LinkerScriptStep.create(b, options.chip, options.sections);

    const microbe_module = cloneModule(b, "microbe", "microbe");
    const chip_module = cloneModule(b, options.chip.dependency_name, options.chip.module_name);

    const config_module = b.createModule(.{
        .source_file = config_step.getOutput(),
        .dependencies = &.{
            .{ .name = "microbe", .module = microbe_module },
            .{ .name = "chip", .module = chip_module },
        },
    });

    microbe_module.dependencies.put("chip", chip_module) catch @panic("OOM");
    microbe_module.dependencies.put("config", config_module) catch @panic("OOM");
    microbe_module.dependencies.put("microbe", microbe_module) catch @panic("OOM");

    chip_module.dependencies.put("chip", chip_module) catch @panic("OOM");
    chip_module.dependencies.put("config", config_module) catch @panic("OOM");
    chip_module.dependencies.put("microbe", microbe_module) catch @panic("OOM");

    var exe = b.addExecutable(.{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .version = options.version,
        .optimize = optimize,
        .max_rss = options.max_rss,
        .link_libc = options.link_libc,
        .use_llvm = options.use_llvm,
        .use_lld = options.use_lld,
        .target = options.chip.core.target,
        .single_threaded = options.chip.single_threaded,
        .linkage = .static,
    });
    exe.strip = false;
    exe.bundle_compiler_rt = options.chip.core.bundle_compiler_rt;
    exe.setLinkerScriptPath(linkerscript_step.getOutput());
    exe.addModule("microbe", microbe_module);
    exe.addModule("config", config_module);
    exe.addModule("chip", chip_module);

    return exe;
}

fn cloneModule(b: *std.Build, dependency_name: []const u8, module_name: []const u8) *std.Build.Module {
    const module = b.dependency(dependency_name, .{}).module(module_name);
    const clone = module.builder.createModule(.{
        .source_file = module.source_file,
    });

    var iter = module.dependencies.iterator();
    while (iter.next()) |entry| {
        clone.dependencies.put(entry.key_ptr.*, entry.value_ptr.*) catch @panic("OOM");
    }

    return clone;
}

pub fn addBinToUf2(b: *std.Build, input_file: std.Build.LazyPath, options: BinToUf2Step.Options) *BinToUf2Step {
    return BinToUf2Step.create(b, input_file, options);
}

pub fn build(b: *std.Build) void {
    _ = b.addModule("microbe", .{
        .source_file = .{ .path = "src/microbe.zig" },
    });
}
