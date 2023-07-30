const std = @import("std");
pub const Core = @import("Core.zig");
pub const Chip = @import("Chip.zig");
pub const Section = @import("Section.zig");
pub const MemoryRegion = @import("MemoryRegion.zig");
const ConfigStep = @import("ConfigStep.zig");
const LinkerScriptStep = @import("LinkerScriptStep.zig");

pub const ExecutableOptions = struct {
    name: []const u8,
    root_source_file: ?std.build.FileSource = null,
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
    const hash = getHash(b, options.chip, options.sections);

    const config_step = ConfigStep.create(b, options.chip, options.sections, hash) catch unreachable;
    const linkerscript_step = LinkerScriptStep.create(b, options.chip, options.sections, hash) catch unreachable;

    const microbe_rt = b.dependency("microbe-rt");
    const rt_module = microbe_rt.module("microbe");

    const config_module = b.createModule(.{
        .source_file = .{ .generated = config_step.generated_file },
    });

    const chip_dep = b.dependency(options.chip.dependency_name);
    const chip_module = chip_dep.module(options.chip.module_name);

    rt_module.dependencies.put("chip", chip_module);
    rt_module.dependencies.put("config", config_module);

    chip_module.dependencies.put("microbe", rt_module);
    chip_module.dependencies.put("config", config_module);

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
    exe.bundle_compiler_rt = options.chip.core.bundle_compiler_rt;
    exe.setLinkerScriptPath(.{ .generated = &linkerscript_step.generated_file });
    exe.addPackage("microbe", rt_module);
    exe.addPackage("config", config_module);
    exe.addModule("chip", chip_module);

    return exe;
}

fn getHash(b: *std.Build, chip: Chip, sections: []const Section) [32]u8 {
    var hash = b.cache.hash;
    hash.add(chip.name);
    hash.add(chip.core.name);

    for (chip.memory_regions) |memory_region| {
        hash.add(memory_region.name);
        hash.add(memory_region.offset);
        hash.add(memory_region.length);
        hash.add(memory_region.access.bits.mask);
    }

    for (sections) |section| {
        hash.add(section.name);
        for (section.contents) |entry| {
            hash.add(entry);
        }
        hash.add(std.mem.asBytes(&section.start_alignment_bytes));
        hash.add(std.mem.asBytes(&section.end_alignment_bytes));
        if (section.rom_region) |region| {
            hash.add(region);
        } else {
            hash.add("~");
        }
        if (section.ram_region) |region| {
            hash.add(region);
        } else {
            hash.add("~");
        }
        if (section.init_value) |v| {
            hash.add(std.mem.asBytes(&v));
        } else {
            hash.add("~");
        }
    }

    return hash.final();
}
