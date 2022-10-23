const std = @import("std");
const microbe = @import("microbe");
const main = microbe.main;

pub const name = microbe.config.core_name;

pub const VectorTable = microbe.chip.VectorTable;
pub const InterruptType = microbe.chip.InterruptType;
const InterruptVector = microbe.chip.InterruptVector;

pub fn isEnabled(comptime interrupt: anytype) bool {

    }

    pub fn setEnabled(comptime interrupt: anytype, enabled: bool) void {

    }

    pub fn areGloballyEnabled() bool {

    }

    pub fn setGloballyEnabled(enabled: bool) void {
        if (enabled) {

        } else {

        }
    }

};

pub fn enable_interrupts() void {
    asm volatile ("cpsie i");
}

pub fn disable_interrupts() void {
    asm volatile ("cpsid i");
}

pub fn enable_fault_interrupts() void {
    asm volatile ("cpsie f");
}
pub fn disable_fault_interrupts() void {
    asm volatile ("cpsid f");
}

pub fn nop() void {
    asm volatile ("nop");
}
pub fn wfi() void {
    asm volatile ("wfi");
}
pub fn wfe() void {
    asm volatile ("wfe");
}
pub fn sev() void {
    asm volatile ("sev");
}
pub fn isb() void {
    asm volatile ("isb");
}
pub fn dsb() void {
    asm volatile ("dsb");
}
pub fn dmb() void {
    asm volatile ("dmb");
}
pub fn clrex() void {
    asm volatile ("clrex");
}

fn isValidInterruptField(field_name: []const u8) bool {
    return !std.mem.startsWith(u8, field_name, "reserved") and
        !std.mem.eql(u8, field_name, "initial_stack_pointer") and
        !std.mem.eql(u8, field_name, "reset");
}

// This comes from the linker and indicates where the stack segment ends, which
// is where the initial stack pointer should be.  It's not a function, but by
// pretending that it is, zig realizes that its address is constant, which doesn't
// happen with declaring it as extern const anyopaque and then taking its address.
// We need it to be comptime constant so that we can put it in the comptime
// constant VectorTable.
extern fn _stack_end() void;

extern fn microbe_main() noreturn;

// Will be imported by microbe.zig to allow system startup.
pub var vector_table: VectorTable = blk: {
    var tmp: VectorTable = .{
        .initial_stack_pointer = _stack_end,
        .Reset = .{ .C = microbe_main },
    };
    if (@hasDecl(main, "interrupts")) {
        if (@typeInfo(main.interrupts) != .Struct)
            @compileLog("root.interrupts must be a struct");

        inline for (@typeInfo(main.interrupts).Struct.decls) |decl| {
            const function = @field(main.interrupts, decl.name);

            if (!@hasField(VectorTable, main.name) or !isValidInterruptField(decl.name)) {
                var msg: []const u8 = "There is no such interrupt as '" ++ decl.name ++ "'. Declarations in 'interrupts' must be one of:\n";
                inline for (std.meta.fields(VectorTable)) |field| {
                    if (isValidInterruptField(field.name)) {
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
