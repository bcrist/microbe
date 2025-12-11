pub const Exception = enum {};
pub const Interrupt = enum {};

pub const Handler = extern union {
    C: *const fn () callconv(.C) void,
    Naked: *const fn () callconv(.Naked) void,

    pub fn wrap(comptime function: anytype) Handler {
        const cc = @typeInfo(@TypeOf(function)).@"fn".calling_convention;
        return switch (cc) {
            .C => .{ .C = function },
            .Naked => .{ .Naked = function },
            .Unspecified => .{
                .C = struct {
                    fn wrapper() callconv(.C) void {
                        @call(.always_inline, function, .{});
                    }
                }.wrapper,
            },
            else => @compileError("unsupported calling convention for exception handler: " ++ @tagName(cc)),
        };
    }

    pub fn address(self: Handler) usize {
        return switch (self) {
            .C => |ptr| @intFromEnum(ptr),
            .Naked => |ptr| @intFromEnum(ptr),
        };
    }
};

pub fn unhandled(comptime e: Exception) Handler {
    const H = struct {
        pub fn unhandled() callconv(.C) noreturn {
            @panic("unhandled " ++ @tagName(e));
        }
    };
    return .{ .C = H.unhandled };
}

pub fn is_enabled(comptime irq: Interrupt) bool {
    _ = irq;
    @compileError("TODO");
}

pub fn set_enabled(comptime irq: Interrupt, comptime enabled: bool) void {
    _ = irq;
    _ = enabled;
    @compileError("TODO");
}

pub const configure_enables = defaults.interrupts.configure_enables;

pub fn get_priority(comptime e: Exception) u8 {
    _ = e;
    @compileError("TODO");
}

pub fn set_priority(comptime e: Exception, priority: u8) void {
    _ = e;
    _ = priority;
    @compileError("TODO");
}

pub const configure_priorities = defaults.interrupts.configure_priorities;

pub fn is_pending(comptime e: Exception) bool {
    _ = e;
    @compileError("TODO");
}

pub fn set_pending(comptime e: Exception, comptime pending: bool) void {
    _ = e;
    _ = pending;
    @compileError("TODO");
}

pub inline fn are_globally_enabled() bool {
    @compileError("TODO");
}

pub inline fn set_globally_enabled(comptime enabled: bool) void {
    _ = enabled;
    @compileError("TODO");
}

pub inline fn current_exception() Exception {
    @compileError("TODO");
}

pub inline fn is_in_handler() bool {
    return current_exception() != .none;
}

pub inline fn wait_for_interrupt() void {
    @compileError("TODO");
}

pub inline fn wait_for_event() void {
    @compileError("TODO");
}

pub inline fn send_event() void {
    @compileError("TODO");
}

const defaults = @import("microbe_internal");
