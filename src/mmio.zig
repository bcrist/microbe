const std = @import("std");
const assert = std.debug.assert;

pub const AccessType = enum { rw, r, w };

pub fn Mmio(comptime T: type, comptime access: AccessType) type {
    const size = @bitSizeOf(T);

    if ((size % 8) != 0) {
        @compileError("size must be divisible by 8!");
    }

    if (!std.math.isPowerOfTwo(size / 8)) {
        @compileError("size must encode a power of two number of bytes!");
    }

    return switch (access) {
        .rw => if (@typeInfo(@TypeOf(T)) == .Int) MmioRwInt(T) else MmioRw(T),
        .r => MmioR(T),
        .w => MmioW(T),
    };
}

fn MmioRw(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Type = T;
        pub const RawType = std.meta.Int(.unsigned, @bitSizeOf(T));

        raw: RawType,

        pub inline fn read(self: *volatile Self) Type {
            return fromInt(Type, self.raw);
        }

        pub inline fn write(self: *volatile Self, val: Type) void {
            self.raw = toInt(RawType, val);
        }

        pub inline fn modify(self: *volatile Self, fields: anytype) void {
            var val = self.read();
            inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                @field(val, field.name) = @field(fields, field.name);
            }
            self.write(val);
        }

        pub inline fn toggle(self: *volatile Self, fields: anytype) void {
            var val = self.read();
            inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                const field_name = @tagName(field.default_value.?);
                @field(val, field_name) = !@field(val, field_name);
            }
            self.write(val);
        }
    };
}

fn MmioRwInt(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Type = T;
        pub const RawType = std.meta.Int(.unsigned, @bitSizeOf(T));

        raw: RawType,

        pub inline fn read(self: *volatile Self) Type {
            return fromInt(Type, self.raw);
        }

        pub inline fn write(self: *volatile Self, val: Type) void {
            self.raw = toInt(RawType, val);
        }
    };
}

fn MmioR(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Type = T;
        pub const RawType = std.meta.Int(.unsigned, @bitSizeOf(T));

        raw: RawType,

        pub inline fn read(self: *volatile Self) Type {
            return fromInt(Type, self.raw);
        }
    };
}

fn MmioW(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Type = T;
        pub const RawType = std.meta.Int(.unsigned, @bitSizeOf(T));

        raw: RawType,

        pub inline fn write(self: *volatile Self, val: Type) void {
            self.raw = toInt(RawType, val);
        }
    };
}

fn toInt(comptime T: type, value: anytype) T {
    return switch (@typeInfo(@TypeOf(value))) {
        .Enum => @intFromEnum(value),
        .Pointer => @intFromPtr(value),
        else => @bitCast(value),
    };
}

fn fromInt(comptime T: type, int_value: anytype) T {
    return switch (@typeInfo(T)) {
        .Enum => @enumFromInt(int_value),
        .Pointer => @ptrFromInt(int_value),
        else => @bitCast(int_value),
    };
}
