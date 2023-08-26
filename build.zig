const std = @import("std");
pub const Core = @import("Core.zig");
pub const Chip = @import("Chip.zig");
pub const Section = @import("Section.zig");
pub const MemoryRegion = @import("MemoryRegion.zig");
const ConfigStep = @import("ConfigStep.zig");
const LinkerScriptStep = @import("LinkerScriptStep.zig");

pub const ExecutableOptions = struct {
    name: []const u8,
    root_source_file: ?std.Build.LazyPath = null,
    chip: Chip,
    sections: []const Section,
    version: ?std.SemanticVersion = null,
    optimize: std.builtin.Mode = .Debug,
    max_rss: usize = 0,
    link_libc: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
};

pub fn addExecutable(b: *std.Build, options: ExecutableOptions) *std.build.LibExeObjStep {
    const config_step = ConfigStep.create(b, options.chip, options.sections);
    const linkerscript_step = LinkerScriptStep.create(b, options.chip, options.sections);

    const chip_dep = b.dependency(options.chip.dependency_name, .{});
    const chip_module = chip_dep.module(options.chip.module_name);
    const rt_module = chip_module.dependencies.get("microbe").?;

    const config_module = b.createModule(.{
        .source_file = config_step.getOutputSource(),
        .dependencies = &.{
            .{ .name = "chip", .module = chip_module },
        },
    });

    var exe = b.addExecutable(.{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .version = options.version,
        .optimize = options.optimize,
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
    exe.setLinkerScriptPath(linkerscript_step.getOutputSource());
    exe.addModule("microbe", rt_module);
    exe.addModule("config", config_module);
    exe.addModule("chip", chip_module);

    return exe;
}

pub fn build(b: *std.Build) void {
    // Expose runtime modules:
    _ = b.addModule("microbe", .{
        .source_file = .{ .path = "src/microbe.zig" },
    });
    _ = b.addModule("chip_util", .{
        .source_file = .{ .path = "src/chip_util.zig" },
    });
    _ = b.addModule("empty", .{
        .source_file = .{ .path = "src/empty.zig" },
    });
}
