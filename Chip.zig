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

pub fn rp2040(comptime flash_size_kibytes: usize) Chip {
    return .{
        .name = std.fmt.comptimePrint("RP2040 ({s} kiB flash)", .{ flash_size_kibytes }),
        .dependency_name = "microbe-rpi",
        .module_name = "rp2040",
        .core = Core.cortex_m0plus,
        .single_threaded = false,
        .memory_regions = &.{
            mainFlash(0x10000000, flash_size_kibytes * 1024),
            mainRam(0x20000000, 256 * 1024),
            executableRam("xip_cache", 0x15000000, 16 * 1024),
            executableRam("sram4", 0x20040000, 4 * 1024),
            executableRam("sram5", 0x20041000, 4 * 1024),
            executableRam("usb_dpram", 0x50100000, 4 * 1024),
        },
    };
}

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
