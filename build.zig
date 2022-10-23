const std = @import("std");
const microbe = @import("src/microbe.zig");

pub fn build(b: *std.build.Builder) void {
    //const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    var example = microbe.addEmbeddedExecutable(b,
        "example.elf",
        "example/main.zig",
        microbe.chips.stm32g030x8,
        microbe.defaultSections(512),
    );
    example.setBuildMode(mode);
    example.install();
}
