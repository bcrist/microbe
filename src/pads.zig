const std = @import("std");
const builtin = @import("builtin");

pub const PadID = @import("root").chip.PadID;

pub const reserve = impl.reserve;
pub const release = impl.release;
pub const isReserved = impl.isReserved;

// This intentionally converts to strings and looks for equality there, so that you can check a
// PadID against a tuple of enum literals, some of which might not be valid PadIDs.  That's
// useful when writing generic chip code, where some packages will be missing some PadIDs that
// other related chips do have.
pub fn isInSet(comptime pad: PadID, comptime set: anytype) bool {
    comptime {
        inline for (set) |p| {
            switch (@typeInfo(@TypeOf(p))) {
                .EnumLiteral => {
                    if (std.mem.eql(u8, @tagName(p), @tagName(pad))) {
                        return true;
                    }
                },
                .Pointer => {
                    if (std.mem.eql(u8, p, @tagName(pad))) {
                        return true;
                    }
                },
                else => @compileError("Expected enum or string literal!"),
            }
        }
        return false;
    }
}

const impl = if (builtin.mode == .Debug) struct {

    // EnumFieldStruct is buggy when using slices as the data type, so we wrap it in a struct:
    const PadOwner = struct {
        name: [*:0]const u8 = "",
    };

    const PadOwners = std.enums.EnumFieldStruct(PadID, PadOwner, .{});
    var pad_owners = PadOwners{};

    fn reserve(comptime pads: []const PadID, comptime owner: [*:0]const u8) void {
        inline for (pads) |pad| {
            setOwner(pad, owner);
        }
    }

    fn release(comptime pads: []const PadID, comptime owner: [*:0]const u8) void {
        inline for (pads) |pad| {
            removeOwner(pad, owner);
        }
    }

    fn setOwner(comptime pad: PadID, comptime owner: [*:0]const u8) void {
        var current_owner = @field(pad_owners, @tagName(pad)).name;
        if (current_owner[0] == 0) {
            @field(pad_owners, @tagName(pad)) = .{ .name = owner };
        } else {
            std.log.err("{s} current owner: {s}", .{ @tagName(pad), current_owner });
            std.log.err("{s} attempted new owner: {s}", .{ @tagName(pad), owner });
            @panic("Attempted to reserve a pad that's already owned!");
        }
    }

    fn removeOwner(comptime pad: PadID, comptime owner: [*:0]const u8) void {
        var current_owner = @field(pad_owners, @tagName(pad)).name;
        if (current_owner == owner) {
            @field(pad_owners, @tagName(pad)) = .{};
        } else {
            std.log.err("{s} current owner: {s}", .{ @tagName(pad), current_owner });
            std.log.err("{s} attempted release by: {s}", .{ @tagName(pad), owner });
            @panic("Attempted to release pad that's not owned by me!");
        }
    }

    fn isReserved(comptime pad: PadID) bool {
        return @field(pad_owners, @tagName(pad)).name[0] != 0;
    }
} else struct {
    var reserved_pads = std.EnumSet(PadID){};

    fn reserve(comptime pads: []const PadID, comptime _: [*:0]const u8) void {
        const set = comptime blk: {
            var temp = std.EnumSet(PadID){};
            inline for (pads) |pad| {
                temp.insert(pad);
            }
            break :blk temp;
        };
        if ((reserved_pads.bits.mask & set.bits.mask) != 0) {
            @panic("Duplicate pad reservation!");
        } else {
            reserved_pads.setUnion(set);
        }
    }

    fn release(comptime pads: []const PadID, comptime _: [*:0]const u8) void {
        const set = comptime blk: {
            var temp = std.EnumSet(PadID){};
            inline for (pads) |pad| {
                temp.insert(pad);
            }
            break :blk temp;
        };
        if ((reserved_pads.bits.mask & set.bits.mask) != set.bits.mask) {
            @panic("Releasing unreserved pad!");
        } else {
            reserved_pads.toggleSet(set);
        }
    }

    fn isReserved(comptime pad: PadID) bool {
        return reserved_pads.contains(pad);
    }
};
