const std = @import("std");
const microbe = @import("microbe");
const cortex = @import("cortex-m.zig");

pub const name = microbe.config.core_name;

pub const init = cortex.init;
pub const flushInstructionCache = cortex.flushInstructionCache;
pub const instructionFence = cortex.instructionFence;
pub const memoryFence = cortex.memoryFence;
pub const softReset = cortex.softReset;

pub const interrupts = struct {
    pub const isEnabled = cortex.isInterruptEnabled;
    pub const setEnabled = cortex.setInterruptEnabled;
    pub const getPriority = cortex.getInterruptPriority;
    pub const setPriority = cortex.setInterruptPriority;
    pub const areGloballyEnabled = cortex.areInterruptsGloballyEnabled;
    pub const setGloballyEnabled = cortex.setInterruptsGloballyEnabled;
    pub const waitForInterrupt = cortex.waitForInterrupt;
    pub const isInterrupting = cortex.isInterrupting;
};
