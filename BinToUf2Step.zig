const std = @import("std");
const BinToUf2Step = @This();

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const File = std.fs.File;
const InstallDir = std.Build.InstallDir;
const Step = std.Build.Step;
const elf = std.elf;
const fs = std.fs;
const io = std.io;
const sort = std.sort;

step: Step,
input_file: std.Build.LazyPath,
base_address: u32,
block_size: u9,
family_id: ?u32,
basename: []const u8,
output_file: std.Build.GeneratedFile,

pub const Options = struct {
    base_address: u32 = 0,
    block_size: u9 = 256,
    family_id: ?u32 = null,
    basename: ?[]const u8 = null,
};

pub fn create(
    owner: *std.Build,
    input_file: std.Build.LazyPath,
    options: Options,
) *BinToUf2Step {
    const self = owner.allocator.create(BinToUf2Step) catch @panic("OOM");
    self.* = BinToUf2Step{
        .step = Step.init(.{
            .id = .custom,
            .name = owner.fmt("bin_to_uf2 {s}", .{input_file.getDisplayName()}),
            .owner = owner,
            .makeFn = make,
        }),
        .input_file = input_file,
        .base_address = options.base_address,
        .block_size = options.block_size,
        .family_id = options.family_id,
        .basename = options.basename orelse input_file.getDisplayName(),
        .output_file = std.Build.GeneratedFile{ .step = &self.step },
    };
    input_file.addStepDependencies(&self.step);
    return self;
}

/// deprecated: use getOutput
pub const getOutputSource = getOutput;

pub fn getOutput(self: *const BinToUf2Step) std.Build.LazyPath {
    return .{ .generated = &self.output_file };
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    _ = prog_node;
    const b = step.owner;
    const self = @fieldParentPtr(BinToUf2Step, "step", step);

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make BinToUf2Step unique. Refresh this with new random
    // bytes when BinToUf2Step implementation is modified incompatibly.
    man.hash.add(@as(u32, 0x4dd3f2c8));

    const full_src_path = self.input_file.getPath(b);
    _ = try man.addFile(full_src_path, null);

    if (try step.cacheHit(&man)) {
        // Cache hit, skip subprocess execution.
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{
            "o", &digest, self.basename,
        });
        return;
    }

    const digest = man.final();
    const cache_path = "o" ++ fs.path.sep_str ++ digest;
    const full_dest_path = try b.cache_root.join(b.allocator, &.{ cache_path, self.basename });
    b.cache_root.handle.makePath(cache_path) catch |err| {
        return step.fail("unable to make path {s}: {s}", .{ cache_path, @errorName(err) });
    };

    if (self.block_size > 476) {
        return step.fail("Block size must be <= 476; found {}", .{ self.block_size });
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const in_file_contents = b.build_root.handle.readFileAlloc(arena.allocator(), full_src_path, 1_000_000_000) catch |err| {
        return step.fail("unable to open '{s}': {s}", .{ full_src_path, @errorName(err) });
    };

    var out_file = b.build_root.handle.createFile(full_dest_path, .{}) catch |err| {
        return step.fail("unable to open '{s}': {s}", .{ full_dest_path, @errorName(err) });
    };
    defer out_file.close();
    var writer = out_file.writer();

    const block_size = self.block_size;
    const num_blocks = (in_file_contents.len + block_size - 1) / block_size;

    var flags: u32 = 0;
    var file_size_or_family_id: u32 = @intCast(in_file_contents.len);
    if (self.family_id) |family_id| {
        _ = family_id;
        flags |= 0x00002000;
        file_size_or_family_id = 0xE48BFF56;
    }

    var address = self.base_address;
    for (0..num_blocks) |block_num| {
        var block = in_file_contents[block_num * block_size ..];
        if (block.len > block_size) {
            block = block[0..block_size];
        }

        try writer.writeIntLittle(u32, 0x0A324655);
        try writer.writeIntLittle(u32, 0x9E5D5157);
        try writer.writeIntLittle(u32, flags);
        try writer.writeIntLittle(u32, address);
        try writer.writeIntLittle(u32, block_size);
        try writer.writeIntLittle(u32, @intCast(block_num));
        try writer.writeIntLittle(u32, @intCast(num_blocks));
        try writer.writeIntLittle(u32, file_size_or_family_id);
        try writer.writeAll(block);
        if (block.len < 476) {
            try writer.writeByteNTimes(0, 476 - block.len);
        }
        try writer.writeIntLittle(u32, 0x0AB16F30);
    }

    self.output_file.path = full_dest_path;
    try man.writeManifest();
}
