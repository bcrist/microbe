/// Disable interrupts, if they're not already disabled.
/// Note on devices with multiple cores, this does not do anything to ensure mutual exclusion with the other core(s).
pub fn enter() Critical_Section {
    const self = Critical_Section{
        .enable_on_leave = chip.interrupts.are_globally_enabled(),
    };
    chip.interrupts.set_globally_enabled(false);
    return self;
}

/// Re-enable interrupts if they were enabled when the critical section was entered.
pub fn leave(self: Critical_Section) void {
    if (self.enable_on_leave) {
        chip.interrupts.set_globally_enabled(true);
    }
}

enable_on_leave: bool,

const Critical_Section = @This();
const chip = @import("chip_interface.zig");
