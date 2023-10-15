const std = @import("std");
const chip = @import("chip");

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

        pub inline fn rmw(self: *volatile Self, fields: anytype) void {
            var val = self.read();
            inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                @field(val, field.name) = @field(fields, field.name);
            }
            self.write(val);
        }

        pub inline fn modify(comptime self: *volatile Self, comptime fields: anytype) void {
            if (@hasDecl(chip, "modifyRegister")) {
                comptime var bits_to_set = fromInt(Type, @as(RawType, 0));
                comptime var bits_to_clear = fromInt(Type, ~@as(RawType, 0));
                inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                    @field(bits_to_set, field.name) = @field(fields, field.name);
                    @field(bits_to_clear, field.name) = @field(fields, field.name);
                }
                chip.modifyRegister(&self.raw, comptime toInt(RawType, bits_to_set), ~comptime toInt(RawType, bits_to_clear));
            } else {
                self.rmw(fields);
            }
        }

        pub fn getBitMask(comptime fields: anytype) RawType {
            return comptime bits: {
                var ones = fromInt(Type, @as(RawType, 0));
                if (@TypeOf(fields) == Type) {
                    ones = fields;
                } else switch (@typeInfo(@TypeOf(fields))) {
                    .Struct => |info| {
                        inline for (info.fields) |field| {
                            @field(ones, field.name) = @field(fields, field.name);
                        }
                    },
                    .EnumLiteral => {
                        const field = @tagName(fields);
                        const FieldType = @TypeOf(@field(ones, field));
                        const RawFieldType = std.meta.Int(.unsigned, @bitSizeOf(FieldType));
                        @field(ones, field) = fromInt(FieldType, ~@as(RawFieldType, 0));
                    },
                    else => @compileError("Expected enum literal or struct"),
                }
                break :bits toInt(RawType, ones);
            };
        }

        pub inline fn toggleBits(comptime self: *volatile Self, comptime fields: anytype) void {
            const bits_to_toggle = comptime getBitMask(fields);
            if (@hasDecl(chip, "toggleRegisterBits")) {
                chip.toggleRegisterBits(&self.raw, bits_to_toggle);
            } else {
                self.raw ^= bits_to_toggle;
            }
        }

        pub inline fn clearBits(comptime self: *volatile Self, comptime fields: anytype) void {
            const bits_to_clear = comptime getBitMask(fields);
            if (@hasDecl(chip, "clearRegisterBits")) {
                chip.clearRegisterBits(&self.raw, bits_to_clear);
            } else if (@hasDecl(chip, "modifyRegister")) {
                chip.modifyRegister(&self.raw, 0, bits_to_clear);
            } else {
                self.raw &= ~bits_to_clear;
            }
        }

        pub inline fn setBits(comptime self: *volatile Self, comptime fields: anytype) void {
            const bits_to_set = comptime getBitMask(fields);
            if (@hasDecl(chip, "setRegisterBits")) {
                chip.setRegisterBits(&self.raw, bits_to_set);
            } else if (@hasDecl(chip, "modifyRegister")) {
                chip.modifyRegister(&self.raw, bits_to_set, 0);
            } else {
                self.raw |= bits_to_set;
            }
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

pub inline fn toInt(comptime T: type, value: anytype) T {
    return switch (@typeInfo(@TypeOf(value))) {
        .Enum => @intFromEnum(value),
        .Pointer => @intFromPtr(value),
        else => @bitCast(value),
    };
}

pub inline fn fromInt(comptime T: type, int_value: anytype) T {
    return switch (@typeInfo(T)) {
        .Enum => @enumFromInt(int_value),
        .Pointer => @ptrFromInt(int_value),
        else => @bitCast(int_value),
    };
}
