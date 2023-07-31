const std = @import("std");
const microbe = @import("microbe.zig");

pub fn build(b: *std.Build) void {
    var example = microbe.addExecutable(b, .{
        .name = "example.elf",
        .root_source_file = .{ .path = "example/main.zig" },
        .chip = microbe.Chip.stm32g030k8,
        .sections = microbe.Section.defaultArmSections(2048),
        .optimize = b.standardOptimizeOption(.{}),
    });
    b.installArtifact(example);

    var objcopy_step = example.addObjCopy(.{ .format = .bin });
    const install_bin_step = b.addInstallBinFile(objcopy_step.getOutputSource(), "example.bin");
    install_bin_step.step.dependOn(&objcopy_step.step);
    b.default_step.dependOn(&install_bin_step.step);

    var flash = b.addSystemCommand(&.{
        "C:\\Program Files (x86)\\STMicroelectronics\\STM32 ST-LINK Utility\\ST-LINK Utility\\ST-LINK_CLI.exe",
        "-c", "SWD", "UR", "LPM",
        "-P", b.getInstallPath(.bin, "example.bin"), "0x08000000",
        "-V", "after_programming",
        "-HardRst", "PULSE=100",
    });
    flash.step.dependOn(&install_bin_step.step);
    const flash_step = b.step("flash", "Flash firmware with ST-LINK");
    flash_step.dependOn(&flash.step);
}
