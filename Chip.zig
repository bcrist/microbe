const std = @import("std");
const Core = @import("Core.zig");
const MemoryRegion = @import("MemoryRegion.zig");
const mainFlash = MemoryRegion.mainFlash;
const mainRam = MemoryRegion.mainRam;
const executableRam = MemoryRegion.executableRam;

const Chip = @This();

name: []const u8,
dependency_name: []const u8,
module_name: []const u8,
core: Core,
memory_regions: []const MemoryRegion,
single_threaded: bool = true,
extra_config: []const ExtraOption = &.{},

pub const ExtraOption = struct {
    name: []const u8,
    value: []const u8,
    escape: bool = false,
};

pub const stm32g030j6 = Chip {
    .name = "STM32G030J6",
    .dependency_name = "microbe-stm32",
    .module_name = "stm32g030j",
    .core = Core.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030f6 = Chip {
    .name = "STM32G030F6",
    .dependency_name = "microbe-stm32",
    .module_name = "stm32g030f",
    .core = Core.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030k6 = Chip {
    .name = "STM32G030K6",
    .dependency_name = "microbe-stm32",
    .module_name = "stm32g030k",
    .core = Core.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030k8 = Chip {
    .name = "STM32G030K8",
    .dependency_name = "microbe-stm32",
    .module_name = "stm32g030k",
    .core = Core.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 64 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030c6 = Chip {
    .name = "STM32G030C6",
    .dependency_name = "microbe-stm32",
    .module_name = "stm32g030c",
    .core = Core.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 32 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};

pub const stm32g030c8 = Chip {
    .name = "STM32G030C8",
    .dependency_name = "microbe-stm32",
    .module_name = "stm32g030c",
    .core = Core.cortex_m0plus,
    .memory_regions = &.{
        mainFlash(0x08000000, 64 * 1024),
        mainRam(0x20000000, 8 * 1024),
    },
};
