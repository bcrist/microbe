const std = @import("std");
const microbe = @import("src/microbe.zig");

pub fn build(b: *std.build.Builder) void {
    var example = microbe.addEmbeddedExecutable(b,
        "example.elf",
        "example/main.zig",
        microbe.chips.stm32g030k8,
        microbe.defaultSections(2048),
    );
    example.setBuildMode(b.standardReleaseOptions());
    example.install();

    var raw = example.installRaw("example.bin", .{});
    const raw_step = b.step("bin", "Convert ELF to bin file");
    raw_step.dependOn(&raw.step);

    var flash = b.addSystemCommand(&.{
        "C:\\Program Files (x86)\\STMicroelectronics\\STM32 ST-LINK Utility\\ST-LINK Utility\\ST-LINK_CLI.exe",
        "-c", "SWD", "UR", "LPM",
        "-P", b.getInstallPath(.bin, "example.bin"), "0x08000000",
        "-V", "after_programming",
        "-HardRst", "PULSE=100",
    });
    flash.step.dependOn(&raw.step);
    const flash_step = b.step("flash", "Flash firmware with ST-LINK");
    flash_step.dependOn(&flash.step);
}
