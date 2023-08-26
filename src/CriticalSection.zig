const chip = @import("root").chip;

const CriticalSection = @This();

enable_on_leave: bool,

pub fn enter() CriticalSection {
    var self = CriticalSection{
        .enable_on_leave = chip.interrupts.areGloballyEnabled(),
    };
    chip.interrupts.setGloballyEnabled(false);
    return self;
}

pub fn leave(self: @This()) void {
    if (self.enable_on_leave) {
        chip.interrupts.setGloballyEnabled(true);
    }
}
