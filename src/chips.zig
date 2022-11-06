const std = @import("std");
const build_config = @import("build_config.zig");
const mainFlash = build_config.mainFlash;
const mainRam = build_config.mainRam;
const MemoryRegion = build_config.MemoryRegion;
const cores = build_config.cores;
const Core = cores.Core;

fn root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}
const root_path = root() ++ "/runtime/chips/";

pub const Chip = struct {
    name: []const u8,
    path: []const u8,
    core: Core,
    memory_regions: []const MemoryRegion,
};

pub const stm32g030j6 = Chip {
    .name = "STM32G030J6",
    .path = root_path ++ "stmicro/stm32g030j.zig",
    .core = cores.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030f6 = Chip {
    .name = "STM32G030F6",
    .path = root_path ++ "stmicro/stm32g030f.zig",
    .core = cores.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030k6 = Chip {
    .name = "STM32G030K6",
    .path = root_path ++ "stmicro/stm32g030k.zig",
    .core = cores.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030k8 = Chip {
    .name = "STM32G030K8",
    .path = root_path ++ "stmicro/stm32g030k.zig",
    .core = cores.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 64 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030c6 = Chip {
    .name = "STM32G030C6",
    .path = root_path ++ "stmicro/stm32g030c.zig",
    .core = cores.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030c8 = Chip {
    .name = "STM32G030C8",
    .path = root_path ++ "stmicro/stm32g030c.zig",
    .core = cores.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 64 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};
