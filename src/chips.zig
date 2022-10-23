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

pub const stm32g030x6 = Chip {
    .name = "STM32G030x6",
    .path = root_path ++ "stmicro/stm32g030.zig",
    .core = cores.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030x8 = Chip {
    .name = "STM32G030x8",
    .path = root_path ++ "stmicro/stm32g030.zig",
    .core = cores.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 64 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

// pub const stm32f103x8 = Chip{
//     .name = "STM32F103x8",
//     .path = root_path ++ "chips/stm32f103/stm32f103.zig",
//     .cpu = cpus.cortex_m3,
//     .memory_regions = &.{
//         MemoryRegion{ .offset = 0x08000000, .length = 64 * 1024, .kind = .flash },
//         MemoryRegion{ .offset = 0x20000000, .length = 20 * 1024, .kind = .ram },
//     },
// };

// pub const stm32f303vc = Chip{
//     .name = "STM32F303VC",
//     .path = root_path ++ "chips/stm32f303/stm32f303.zig",
//     .cpu = cpus.cortex_m4,
//     .memory_regions = &.{
//         MemoryRegion{ .offset = 0x08000000, .length = 256 * 1024, .kind = .flash },
//         MemoryRegion{ .offset = 0x20000000, .length = 40 * 1024, .kind = .ram },
//     },
// };

// pub const stm32f407vg = Chip{
//     .name = "STM32F407VG",
//     .path = root_path ++ "chips/stm32f407/stm32f407.zig",
//     .cpu = cpus.cortex_m4,
//     .memory_regions = &.{
//         MemoryRegion{ .offset = 0x08000000, .length = 1024 * 1024, .kind = .flash },
//         MemoryRegion{ .offset = 0x20000000, .length = 128 * 1024, .kind = .ram },
//         // CCM RAM
//         MemoryRegion{ .offset = 0x10000000, .length = 64 * 1024, .kind = .ram },
//     },
// };

// pub const stm32f429zit6u = Chip{
//     .name = "STM32F429ZIT6U",
//     .path = root_path ++ "chips/stm32f429/stm32f429.zig",
//     .cpu = cpus.cortex_m4,
//     .memory_regions = &.{
//         MemoryRegion{ .offset = 0x08000000, .length = 2048 * 1024, .kind = .flash },
//         MemoryRegion{ .offset = 0x20000000, .length = 192 * 1024, .kind = .ram },
//         // CCM RAM
//         MemoryRegion{ .offset = 0x10000000, .length = 64 * 1024, .kind = .ram },
//     },
// };

// pub const nrf52832 = Chip{
//     .name = "nRF52832",
//     .path = root_path ++ "chips/nrf52/nrf52.zig",
//     .cpu = cpus.cortex_m4,
//     .memory_regions = &.{
//         MemoryRegion{ .offset = 0x00000000, .length = 0x80000, .kind = .flash },
//         MemoryRegion{ .offset = 0x20000000, .length = 0x10000, .kind = .ram },
//     },
// };

// pub const atsame51j20a = Chip{
//     .name = "ATSAME51J20A",
//     .path = root_path ++ "chips/atsame51j20a/atsame51j20a.zig",
//     .cpu = cpus.cortex_m4,
//     .memory_regions = &.{
//         // SAM D5x/E5x Family Data Sheet page 53
//         MemoryRegion{ .offset = 0x00000000, .length = 1024 * 1024, .kind = .flash },
//         MemoryRegion{ .offset = 0x20000000, .length = 256 * 1024, .kind = .ram },
//     },
// };