pub fn Bitset_Resource_Validator(comptime K: type, comptime resource_name: []const u8) type {
    return struct {
        var reservations = std.enums.EnumSet(K).initEmpty();

        pub fn reserve(comptime resource: K, owner: [*:0]const u8) void {
            if (!reservations.contains(resource)) {
                reservations.insert(resource);
            } else {
                std.log.err("{s} attempted new owner: {s}", .{ @tagName(resource), owner });
                @panic("Attempted to reserve a " ++ resource_name ++ " that's already owned!");
            }
        }

        pub fn reserve_all(comptime array: []const K, owner: [*:0]const u8) void {
            inline for (array) |resource| {
                reserve(resource, owner);
            }
        }

        pub fn is_reserved(comptime resource: K) bool {
            return reservations.contains(resource);
        }

        pub fn get_owner(comptime resource: K) ?[*:0]const u8 {
            return if (is_reserved(resource)) "?" else null;
        }
    };
}

pub fn Runtime_Resource_Validator(comptime K: type, comptime resource_name: []const u8) type {
    return struct {
        var owners: std.enums.EnumFieldStruct(K, Owner, .{}) = .{};

        pub fn reserve(comptime resource: K, owner: [*:0]const u8) void {
            const current_owner = @field(owners, @tagName(resource)).name;
            if (current_owner[0] == 0) {
                @field(owners, @tagName(resource)) = .{ .name = owner };
            } else {
                std.log.err("{s} current owner: {s}", .{ @tagName(resource), current_owner });
                std.log.err("{s} attempted new owner: {s}", .{ @tagName(resource), owner });
                @panic("Attempted to reserve a " ++ resource_name ++ " that's already owned!");
            }
        }

        pub fn reserve_all(comptime resources: []const K, owner: [*:0]const u8) void {
            inline for (resources) |resource| {
                reserve(resource, owner);
            }
        }

        pub fn release(comptime resource: K, owner: [*:0]const u8) void {
            const current_owner = @field(owners, @tagName(resource)).name;
            if (current_owner == owner) {
                @field(owners, @tagName(resource)) = .{};
            } else {
                std.log.err("{s} current owner: {s}", .{ @tagName(resource), current_owner });
                std.log.err("{s} attempted release by: {s}", .{ @tagName(resource), owner });
                @panic("Attempted to release " ++ resource_name ++ " that's not owned by me!");
            }
        }

        pub fn release_all(comptime resources: []const K, owner: [*:0]const u8) void {
            inline for (resources) |resource| {
                release(resource, owner);
            }
        }

        pub fn are_any_reserved(comptime resources: []const K) bool {
            inline for (resources) |resource| {
                if (is_reserved(resource)) {
                    return true;
                }
            }
            return false;
        }

        pub fn is_reserved(comptime resource: K) bool {
            return @field(owners, @tagName(resource)).name[0] != 0;
        }

        pub fn get_owner(comptime resource: K) ?[*:0]const u8 {
            const owner = @field(owners, @tagName(resource)).name;
            return if (owner[0] == 0) null else owner;
        }

    };
}

pub fn Null_Resource_Validator(comptime K: type, comptime _: []const u8) type {
    return struct {
        pub fn reserve(comptime _: K, _: [*:0]const u8) void {}
        pub fn reserve_all(comptime _: []const K, _: [*:0]const u8) void {}
        pub fn release(comptime _: K, _: [*:0]const u8) void {}
        pub fn release_all(comptime _: []const K, _: [*:0]const u8) void {}
        pub fn are_any_reserved(comptime _: []const K) bool { return false; }
        pub fn is_reserved(comptime _: K) bool { return false; }
        pub fn get_owner(comptime _: K) ?[*:0]const u8 { return null; }
    };
}

const Owner = struct {
    name: [*:0]const u8 = "",
};

const std = @import("std");
