/// Disable interrupts, if they're not already disabled.
/// Note on devices with multiple cores, this does not do anything to ensure mutual exclusion with the other core(s).
pub fn enter() CriticalSection {
    var self = CriticalSection{
        .enable_on_leave = chip.interrupts.areGloballyEnabled(),
    };
    chip.interrupts.setGloballyEnabled(false);
    return self;
}

/// Re-enable interrupts if they were enabled when the critical section was entered.
pub fn leave(self: CriticalSection) void {
    if (self.enable_on_leave) {
        chip.interrupts.setGloballyEnabled(true);
    }
}

enable_on_leave: bool,

const CriticalSection = @This();

const chip = @import("chip_interface.zig");
