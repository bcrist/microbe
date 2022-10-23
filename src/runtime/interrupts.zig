const std = @import("std");
const chip = @import("chip");

pub const InterruptType = chip.interrupts.InterruptType;

pub fn isEnabled(comptime interrupt: anytype) bool {
    return chip.interrupts.isEnabled(std.enums.nameCast(InterruptType, interrupt));
}

pub fn setEnabled(comptime interrupt: anytype, enabled: bool) void {
    chip.interrupts.setEnabled(std.enums.nameCast(InterruptType, interrupt), enabled);
}

pub fn configureEnables(comptime config: anytype) void {
    if (@hasDecl(chip.interrupts, "configureEnables")) {
        chip.interrupts.configureEnabled(config);
    } else {
        const info = @typeInfo(@TypeOf(config));
        switch (info) {
            .Struct => |struct_info| {
                for (struct_info.fields) |field| {
                    setEnabled(field.name, @field(config, field.name));
                }
            },
            else => {
                @compileError("Expected a struct literal containing interrupts to enable or disable!");
            },
        }
    }
}

pub usingnamespace if (@hasDecl(chip.interrupts, "setGloballyEnabled") and @hasDecl(chip.interrupts, "areGloballyEnabled"))
    struct {
        pub const areGloballyEnabled = chip.interrupts.areGloballyEnabled;
        pub const setGloballyEnabled = chip.interrupts.setGloballyEnabled;

        /// Enters a critical section and disables interrupts globally.
        /// Call `.leave()` on the return value to restore the previous state.
        pub fn enterCriticalSection() CriticalSection {
            var section = CriticalSection {
                .enable_on_leave = areGloballyEnabled(),
            };
            setGloballyEnabled(false);
            return section;
        }

        /// A critical section structure that allows restoring the interrupt
        /// status that was set before entering.
        const CriticalSection = struct {
            enable_on_leave: bool,

            /// Leaves the critical section and restores the interrupt state.
            pub fn leave(self: @This()) void {
                if (self.enable_on_leave) {
                    setGloballyEnabled(true);
                }
            }
        };
    }
else struct {};

pub usingnamespace if (@hasDecl(chip.interrupts, "waitForInterrupt"))
    struct {
        pub const waitForInterrupt = chip.interrupts.waitForInterrupt;
    }
else struct {};

pub usingnamespace if (@hasDecl(chip.interrupts, "isInterrupting"))
    struct {
        pub const isInterrupting = chip.interrupts.isInterrupting;
    }
else struct {};

pub usingnamespace if (@hasDecl(chip.interrupts, "setPriority") and @hasDecl(chip.interrupts, "getPriority"))
    struct {
        pub fn getPriority(comptime interrupt: anytype) u8 {
            return chip.interrupts.getPriority(std.enums.nameCast(InterruptType, interrupt));
        }

        pub fn setPriority(comptime interrupt: anytype, priority: u8) void {
            chip.interrupts.setPriority(std.enums.nameCast(InterruptType, interrupt), priority);
        }
    }
else struct {};

pub usingnamespace if (@hasDecl(chip.interrupts, "ext")) chip.interrupts.ext else struct {};
