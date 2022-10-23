const std = @import("std");

fn root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}
const root_path = root() ++ "/runtime/cores/";

pub const Core = struct {
    name: []const u8,
    path: []const u8,
    target: std.zig.CrossTarget,
};

pub const cortex_m0 = Core {
    .name = "ARM Cortex-M0",
    .path = root_path ++ "arm/cortex-m0.zig",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0 },
        .os_tag = .freestanding,
        .abi = .none,
    },
};

pub const cortex_m0plus = Core {
    .name = "ARM Cortex-M0+",
    .path = root_path ++ "arm/cortex-m0plus.zig",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0plus },
        .os_tag = .freestanding,
        .abi = .none,
    },
};

pub const cortex_m3 = Core {
    .name = "ARM Cortex-M3",
    .path = root_path ++ "arm/cortex-m3.zig",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m3 },
        .os_tag = .freestanding,
        .abi = .none,
    },
};

pub const cortex_m4 = Core {
    .name = "ARM Cortex-M4",
    .path = root_path ++ "arm/cortex-m4.zig",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .none,
    },
};

pub const cortex_m4fpu = Core {
    .name = "ARM Cortex-M4 with FPU",
    .path = root_path ++ "arm/cortex-m4fpu.zig",
    .target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .eabihf,
    },
};
