const Source = struct {
    block_size: usize,
    family_id: ?u32,
    base_address: u32,
    data: []const u8,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var output_path: []const u8 = "out.uf2";
    var sources = try std.ArrayList(Source).initCapacity(arena.allocator(), 2);

    var base_address: u32 = 0;
    var block_size: u32 = 256;
    var family_id: ?u32 = null;
    var expected_source = false;

    var arg_iter = try std.process.argsWithAllocator(arena.allocator());
    defer arg_iter.deinit();
    _ = arg_iter.next(); // exe name
    while (arg_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            output_path = arg_iter.next() orelse return error.ExpectedOutputPath;
        } else if (std.mem.eql(u8, arg, "--base-addr") or std.mem.eql(u8, arg, "-a")) {
            const base_addr_str = arg_iter.next() orelse return error.ExpectedBaseAddress;
            base_address = std.fmt.parseInt(u32, base_addr_str, 0) catch return error.InvalidBaseAddress;
            expected_source = true;
        } else if (std.mem.eql(u8, arg, "--block-size")) {
            const block_size_str = arg_iter.next() orelse return error.ExpectedBlockSize;
            block_size = std.fmt.parseInt(u32, block_size_str, 0) catch return error.InvalidBlockSize;
            if (block_size > 476) {
                try std.io.getStdErr().writer().print("{} is larger than the maximum allowed block size of 476", .{ block_size });
                return error.InvalidBlockSize;
            }
            expected_source = true;
        } else if (std.mem.eql(u8, arg, "--family")) {
            const id_str = arg_iter.next() orelse return error.ExpectedFamilyID;
            if (std.mem.startsWith(u8, id_str, "rp") or std.mem.startsWith(u8, id_str, "RP")) {
                var suffix = id_str[2..];
                if (std.mem.eql(u8, suffix, "2040")) {
                    family_id = 0xE48BFF56;
                } else if (std.ascii.eqlIgnoreCase(suffix, "_absolute")) {
                    family_id = 0xE48BFF57;
                } else if (std.ascii.eqlIgnoreCase(suffix, "_data")) {
                    family_id = 0xE48BFF58;
                } else if (std.mem.startsWith(u8, suffix, "2350_") or std.mem.startsWith(u8, suffix, "2354_")) {
                    suffix = suffix[5..];
                    if (std.ascii.eqlIgnoreCase(suffix, "arm_secure")) {
                        family_id = 0xE48BFF59;
                    } else if (std.ascii.eqlIgnoreCase(suffix, "arm_nonsecure")) {
                        family_id = 0xE48BFF5B;
                    } else if (std.ascii.eqlIgnoreCase(suffix, "risc_v")) {
                        family_id = 0xE48BFF5A;
                    } else {
                        try std.io.getStdErr().writer().print(
                            \\Expected family ID to be one of:
                            \\   {s}_arm_nonsecure
                            \\   {s}_arm_secure
                            \\   {s}_risc_v
                            , .{ id_str[0..6], id_str[0..6], id_str[0..6] });
                        return error.InvalidFamilyID;
                    }
                }
            } else {
                family_id = std.fmt.parseInt(u32, id_str, 0) catch return error.InvalidFamilyID;
            }
            expected_source = true;
        } else {
            const file_contents = try std.fs.cwd().readFileAlloc(arena.allocator(), arg, 1_000_000_000);
            try sources.append(.{
                .block_size = block_size,
                .family_id = family_id,
                .base_address = base_address,
                .data = file_contents,
            });
            expected_source = false;
            base_address = 0;
        }
    }

    if (sources.items.len == 0) {
        return error.ExpectedBinFile;
    }

    if (expected_source) {
        try std.io.getStdErr().writer().writeAll("`--base-addr`, `--block-size` and `--family` must be specified before the binary file(s) they affect");
        return error.InvalidUsage;
    }

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    var writer = out_file.writer();

    for (sources.items) |source| {
        const num_blocks = (source.data.len + source.block_size - 1) / source.block_size;

        var flags: u32 = 0;
        if (source.family_id) |_| flags |= 0x2000;

        var address = source.base_address;
        for (0..num_blocks) |block_num| {
            var block = source.data[block_num * block_size ..];
            if (block.len > block_size) {
                block = block[0..block_size];
            }

            try writer.writeInt(u32, 0x0A324655, .little); // UF2 magic number
            try writer.writeInt(u32, 0x9E5D5157, .little); // UF2 magic number
            try writer.writeInt(u32, flags, .little);
            try writer.writeInt(u32, address, .little);
            try writer.writeInt(u32, block_size, .little);
            try writer.writeInt(u32, @intCast(block_num), .little);
            try writer.writeInt(u32, @intCast(num_blocks), .little);
            try writer.writeInt(u32, source.family_id orelse @intCast(source.data.len), .little);
            try writer.writeAll(block);
            if (block.len < 476) {
                try writer.writeByteNTimes(0, 476 - block.len);
            }
            try writer.writeInt(u32, 0x0AB16F30, .little); // UF2 magic number

            address += block_size;
        }
    }
}

const std = @import("std");
