const std = @import("std");
const microbe = @import("microbe");
const main = microbe.main;
const chip = microbe.chip;

const VectorTable = chip.VectorTable;
const InterruptType = chip.InterruptType;
const InterruptVector = chip.InterruptVector;

pub fn init() void {
    // Nothing to do here, but this ensures we will export .vector_table
}

pub fn flushInstructionCache() void {
    asm volatile ("isb");
}
pub fn instructionFence() void {
    asm volatile ("dsb");
}
pub fn memoryFence() void {
    asm volatile ("dmb");
}

// This comes from the linker and indicates where the stack segment ends, which
// is where the initial stack pointer should be.  It's not a function, but by
// pretending that it is, zig realizes that its address is constant, which doesn't
// happen with declaring it as extern const anyopaque and then taking its address.
// We need it to be comptime constant so that we can put it in the comptime
// constant VectorTable.
extern fn _stack_end() void;

extern fn microbe_main() noreturn;

export const vector_table: VectorTable linksection(".vector_table") = blk: {
    var tmp: VectorTable = .{
        .initial_stack_pointer = _stack_end,
        .Reset = .{ .C = microbe_main },
    };
    if (@hasDecl(main, "interrupts")) {
        if (@typeInfo(main.interrupts) != .Struct)
            @compileLog("root.interrupts must be a struct");

        inline for (@typeInfo(main.interrupts).Struct.decls) |decl| {
            const function = @field(main.interrupts, decl.name);

            if (!@hasField(VectorTable, decl.name) or !@hasField(InterruptType, decl.name)) {
                var msg: []const u8 = "There is no such interrupt as '" ++ decl.name ++ "'. Declarations in 'interrupts' must be one of:\n";
                inline for (std.meta.fields(VectorTable)) |field| {
                    if (@hasField(InterruptType, field.name)) {
                        msg = msg ++ "    " ++ field.name ++ "\n";
                    }
                }

                @compileError(msg);
            }

            @field(tmp, decl.name) = createInterruptVector(function);
        }
    }
    break :blk tmp;
};

fn createInterruptVector(comptime function: anytype) InterruptVector {
    const calling_convention = @typeInfo(@TypeOf(function)).Fn.calling_convention;
    return switch (calling_convention) {
        .C => .{ .C = function },
        .Naked => .{ .Naked = function },
        // for unspecified calling convention we are going to generate small wrapper
        .Unspecified => .{
            .C = struct {
                fn wrapper() callconv(.C) void {
                    if (calling_convention == .Unspecified) // TODO: workaround for some weird stage1 bug
                        @call(.{ .modifier = .always_inline }, function, .{});
                }
            }.wrapper,
        },

        else => |val| {
            const conv_name = inline for (std.meta.fields(std.builtin.CallingConvention)) |field| {
                if (val == @field(std.builtin.CallingConvention, field.name))
                    break field.name;
            } else unreachable;

            @compileError("unsupported calling convention for interrupt vector: " ++ conv_name);
        },
    };
}

pub fn isInterruptEnabled(comptime interrupt: InterruptType) bool {
    if (@enumToInt(interrupt) >= 0) {
        return @field(chip.registers.SCS.NVIC.ISER.read(), @tagName(interrupt)) == 1;
    } else {
        return true;
    }
}

pub fn setInterruptEnabled(comptime interrupt: InterruptType, comptime enabled: bool) void {
    if (@enumToInt(interrupt) >= 0) {
        if (enabled) {
            const ISER_Type = chip.registers.SCS.NVIC.ISER.underlying_type;
            const val = ISER_Type {};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ISER.write(val);
        } else {
            const ICER_Type = chip.registers.SCS.NVIC.ICER.underlying_type;
            const val = ICER_Type {};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ICER.write(val);
        }
    } else {
        @compileError("This exception is permanently enabled!");
    }
}

pub fn getInterruptPriority(comptime interrupt: InterruptType) u8 {
    if (@enumToInt(interrupt) >= 0) {
        const reg_name = std.fmt.comptimePrint("IP{}", .{ @intCast(u5, @enumToInt(interrupt)) / 4 });
        const val = @field(chip.registers.SCS.NVIC, reg_name).read();
        return @shlExact(@intCast(u8, @field(val, @tagName(interrupt))), 4);
    } else return @shlExact(@intCast(u8, switch (interrupt) {
        .SVCall => chip.registers.SCS.SCB.SHPR2.read().SVCALLPRI,
        .PendSV => chip.registers.SCS.SCB.SHPR3.read().PENDSVPRI,
        .SysTick => chip.registers.SCS.SCB.SHPR3.read().SYSTICKPRI,
        else => @compileError("Exception priority is fixed!"),
    }), 4);
}

pub fn setInterruptPriority(comptime interrupt: InterruptType, priority: u8) void {
    const p4: u4 = @intCast(u4, @shrExact(priority, 4));
    if (@enumToInt(interrupt) >= 0) {
        const reg_name = std.fmt.comptimePrint("IP{}", .{ @intCast(u5, @enumToInt(interrupt)) / 4 });
        const val = @field(chip.registers.SCS.NVIC, reg_name).read();
        @field(val, @tagName(interrupt)) = p4;
        @field(chip.registers.SCS.NVIC, reg_name).write(val);
    } else switch (interrupt) {
        .SVCall => chip.registers.SCS.SCB.SHPR2.modify(.{ .SVCALLPRI = p4 }),
        .PendSV => chip.registers.SCS.SCB.SHPR3.modify(.{ .PENDSVPRI = p4 }),
        .SysTick => chip.registers.SCS.SCB.SHPR3.modify(.{ .SYSTICKPRI = p4 }),
        else => @compileError("Exception priority is fixed!"),
    }
}

pub fn isInterruptPending(comptime interrupt: InterruptType) bool {
    if (@enumToInt(interrupt) >= 0) {
        return @field(chip.registers.SCS.NVIC.ISPR.read(), @tagName(interrupt)) != 0;
    } else return switch (interrupt) {
        .NMI => chip.registers.SCS.NVIC.ICSR.read().NMIPENDSET != 0,
        .PendSV => chip.registers.SCS.NVIC.ICSR.read().PENDSVSET != 0,
        .SysTick => chip.registers.SCS.NVIC.ICSR.read().PENDSTSET != 0,
        else => @compileError("Unsupported exception type!"),
    };
}

pub fn setInterruptPending(comptime interrupt: InterruptType, comptime pending: bool) void {
    if (@enumToInt(interrupt) >= 0) {
        if (pending) {
            const ISPR_Type = chip.registers.SCS.NVIC.ISPR.underlying_type;
            const val = ISPR_Type {};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ISPR.write(val);
        } else {
            const ICPR_Type = chip.registers.SCS.NVIC.ICPR.underlying_type;
            const val = ICPR_Type {};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ICPR.write(val);
        }
    } else switch (interrupt) {
        .NMI => {
            if (!pending) {
                @compileError("NMI can't be unpended!");
            }
            const ICSR_Type = chip.registers.SCS.NVIC.ICSR.underlying_type;
            const val = ICSR_Type {};
            @field(val, @tagName(interrupt)) = 1;
            chip.registers.SCS.NVIC.ICSR.write(val);
        },
        .PendSV => {
            const ICSR_Type = chip.registers.SCS.NVIC.ICSR.underlying_type;
            const val = ICSR_Type {};
            if (pending) {
                val.PENDSVSET = 1;
            } else {
                val.PENDSVSET = 0;
            }
            chip.registers.SCS.NVIC.ICSR.write(val);
        },
        .SysTick => {
            const ICSR_Type = chip.registers.SCS.NVIC.ICSR.underlying_type;
            const val = ICSR_Type {};
            if (pending) {
                val.PENDSTSET = 1;
            } else {
                val.PENDSTSET = 0;
            }
            chip.registers.SCS.NVIC.ICSR.write(val);
        },
        else => @compileError("Unsupported exception type!"),
    }
}

pub fn areInterruptsGloballyEnabled() bool {
    return !asm volatile ("mrs r0, primask" : [ret] "={r0}" (-> bool) : : "r0");
}

pub fn setInterruptsGloballyEnabled(comptime enabled: bool) void {
    if (enabled) {
        asm volatile ("cpsie i");
    } else {
        asm volatile ("cpsid i");
    }
}

pub fn waitForInterrupt() void {
    asm volatile ("wfi");
}

pub fn isInterrupting() bool {
    return !asm volatile ("mrs r0, ipsr" : [ret] "={r0}" (-> bool) : : "r0");
}

pub fn softReset() void {
    chip.registers.SCS.SCB.AIRCR.write(.{
        .SYSRESETREQ = 1,
        .VECTKEY = 0x05FA,
    });
}
