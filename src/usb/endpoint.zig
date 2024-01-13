pub const Index = u4;

pub const Direction = enum (u1) {
    out = 0, // host to device
    in = 1, // device to host
};

pub const Transfer_Kind = enum (u2) {
    control = 0,
    isochronous = 1,
    bulk = 2,
    interrupt = 3,
};

// Only applies to Transfer_Kind.isochronous; otherwise use .none
pub const Synchronization = enum (u2) {
    none = 0,
    asynchronous = 1,
    adaptive = 2,
    synchronous = 3,
};

pub const Usage = enum (u2) {
    data = 0,
    feedback = 1,
    implicit_feedback_data = 2,
    _,
};

pub const Address = packed struct (u8) {
    ep: Index,
    _reserved: u3 = 0,
    dir: Direction,
};

pub const Buffer_Info = struct {
    address: Address,
    buffer: []volatile u8,
    final_buffer: bool,
};
