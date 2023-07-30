const std = @import("std");

const Core = @This();

name: []const u8,
target: std.zig.CrossTarget,
bundle_compiler_rt: bool = true,

pub const cortex_m0 = Core {
    .name = "ARM Cortex-M0",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0 },
        .os_tag = .freestanding,
        .abi = .eabi,
    },
};

pub const cortex_m0plus = Core {
    .name = "ARM Cortex-M0+",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0plus },
        .os_tag = .freestanding,
        .abi = .eabi,
    },
};

pub const cortex_m3 = Core {
    .name = "ARM Cortex-M3",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m3 },
        .os_tag = .freestanding,
        .abi = .eabi,
    },
};

pub const cortex_m4 = Core {
    .name = "ARM Cortex-M4",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .eabi,
    },
};

pub const cortex_m4fpu = Core {
    .name = "ARM Cortex-M4 with FPU",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .eabihf,
    },
};
