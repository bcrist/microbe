const std = @import("std");
const chip = @import("chip");
const util = @import("util.zig");

const to_int = util.to_int;
const from_int = util.from_int;

pub const Access_Type = enum { rw, r, w };

pub fn MMIO(comptime T: type, comptime access: Access_Type) type {
    const size = @bitSizeOf(T);

    if ((size % 8) != 0) {
        @compileError("size must be divisible by 8!");
    }

    if (!std.math.isPowerOfTwo(size / 8)) {
        @compileError("size must encode a power of two number of bytes!");
    }

    return switch (access) {
        .rw => if (@typeInfo(@TypeOf(T)) == .int) MMIO_RW_Int(T) else MMIO_RW(T),
        .r => MMIO_R(T),
        .w => MMIO_W(T),
    };
}

fn MMIO_RW(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Type = T;
        pub const Raw_Type = std.meta.Int(.unsigned, @bitSizeOf(T));

        raw: Raw_Type,

        pub inline fn read(self: *volatile Self) Type {
            return from_int(Type, self.raw);
        }

        pub inline fn write(self: *volatile Self, val: Type) void {
            self.raw = to_int(Raw_Type, val);
        }

        pub inline fn rmw(self: *volatile Self, fields: anytype) void {
            var val = self.read();
            inline for (@typeInfo(@TypeOf(fields)).@"struct".fields) |field| {
                @field(val, field.name) = @field(fields, field.name);
            }
            self.write(val);
        }

        pub inline fn modify(comptime self: *volatile Self, comptime fields: anytype) void {
            if (@hasDecl(chip, "modify_register")) {
                comptime var bits_to_set = from_int(Type, @as(Raw_Type, 0));
                comptime var bits_to_clear = from_int(Type, ~@as(Raw_Type, 0));
                inline for (@typeInfo(@TypeOf(fields)).@"struct".fields) |field| {
                    @field(bits_to_set, field.name) = @field(fields, field.name);
                    @field(bits_to_clear, field.name) = @field(fields, field.name);
                }
                chip.modify_register(&self.raw, comptime to_int(Raw_Type, bits_to_set), ~comptime to_int(Raw_Type, bits_to_clear));
            } else {
                self.rmw(fields);
            }
        }

        pub fn get_bit_mask(comptime fields: anytype) Raw_Type {
            return comptime bits: {
                var ones = from_int(Type, @as(Raw_Type, 0));
                if (@TypeOf(fields) == Type) {
                    ones = fields;
                } else switch (@typeInfo(@TypeOf(fields))) {
                    .@"struct" => |info| {
                        for (info.fields) |field| {
                            @field(ones, field.name) = @field(fields, field.name);
                        }
                    },
                    .enum_literal => {
                        const field = @tagName(fields);
                        const Field_Type = @TypeOf(@field(ones, field));
                        const Raw_Field_Type = std.meta.Int(.unsigned, @bitSizeOf(Field_Type));
                        @field(ones, field) = from_int(Field_Type, ~@as(Raw_Field_Type, 0));
                    },
                    else => @compileError("Expected enum literal or struct"),
                }
                break :bits to_int(Raw_Type, ones);
            };
        }

        pub inline fn toggle_bits(comptime self: *volatile Self, comptime fields: anytype) void {
            const bits_to_toggle = comptime get_bit_mask(fields);
            if (@hasDecl(chip, "toggle_register_bits")) {
                chip.toggle_register_bits(&self.raw, bits_to_toggle);
            } else {
                self.raw ^= bits_to_toggle;
            }
        }

        pub inline fn clear_bits(comptime self: *volatile Self, comptime fields: anytype) void {
            const bits_to_clear = comptime get_bit_mask(fields);
            if (@hasDecl(chip, "clear_register_bits")) {
                chip.clear_register_bits(&self.raw, bits_to_clear);
            } else if (@hasDecl(chip, "modify_register")) {
                chip.modify_register(&self.raw, 0, bits_to_clear);
            } else {
                self.raw &= ~bits_to_clear;
            }
        }

        pub inline fn set_bits(comptime self: *volatile Self, comptime fields: anytype) void {
            const bits_to_set = comptime get_bit_mask(fields);
            if (@hasDecl(chip, "set_register_bits")) {
                chip.set_register_bits(&self.raw, bits_to_set);
            } else if (@hasDecl(chip, "modify_register")) {
                chip.modify_register(&self.raw, bits_to_set, 0);
            } else {
                self.raw |= bits_to_set;
            }
        }
    };
}

fn MMIO_RW_Int(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Type = T;
        pub const Raw_Type = std.meta.Int(.unsigned, @bitSizeOf(T));

        raw: Raw_Type,

        pub inline fn read(self: *volatile Self) Type {
            return from_int(Type, self.raw);
        }

        pub inline fn write(self: *volatile Self, val: Type) void {
            self.raw = to_int(Raw_Type, val);
        }
    };
}

fn MMIO_R(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Type = T;
        pub const Raw_Type = std.meta.Int(.unsigned, @bitSizeOf(T));

        raw: Raw_Type,

        pub inline fn read(self: *volatile Self) Type {
            return from_int(Type, self.raw);
        }
    };
}

fn MMIO_W(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Type = T;
        pub const Raw_Type = std.meta.Int(.unsigned, @bitSizeOf(T));

        raw: Raw_Type,

        pub inline fn write(self: *volatile Self, val: Type) void {
            self.raw = to_int(Raw_Type, val);
        }
    };
}
