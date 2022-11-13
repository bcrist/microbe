// const std = @import("std");
// const microbe = @import("root");
// const chip = microbe.chip;

// pub const PadID = chip.gpio.PadID;

// pub const Config = struct {
//     tck: PadID,
//     tms: PadID,
//     tdo: PadID,
//     tdi: PadID,
//     max_frequency: comptime_int,
// };

// pub const State = enum {
//     unknown,
//         // TMS 1 -> unknown2
//     unknown2,
//         // TMS 1 -> unknown3
//     unknown3,
//         // TMS 1 -> unknown4
//     unknown4,
//         // TMS 1 -> unknown5
//     unknown5,
//         // TMS 1 -> reset
//     reset,
//         // TMS 0 -> idle
//         // TMS 1 -> reset
//     idle,
//         // TMS 0 -> idle
//         // TMS 1 -> DR_select
//     DR_select,
//         // TMS 0 -> DR_capture
//         // TMS 1 -> IR_select
//     DR_capture,
//         // TMS 0 -> DR_shift
//         // TMS 1 -> DR_exit1
//     DR_shift,
//         // TMS 0 -> DR_shift
//         // TMS 1 -> DR_exit1
//     DR_exit1,
//         // TMS 0 -> DR_pause
//         // TMS 1 -> DR_update
//     DR_pause,
//         // TMS 0 -> DR_pause
//         // TMS 1 -> DR_exit2
//     DR_exit2,
//         // TMS 0 -> DR_shift
//         // TMS 1 -> DR_update
//     DR_update,
//         // TMS 0 -> idle
//         // TMS 1 -> DR_select
//     IR_select,
//         // TMS 0 -> IR_capture
//         // TMS 1 -> reset
//     IR_capture,
//         // TMS 0 -> IR_shift
//         // TMS 1 -> IR_exit1
//     IR_shift,
//         // TMS 0 -> IR_shift
//         // TMS 1 -> IR_exit1
//     IR_exit1,
//         // TMS 0 -> IR_pause
//         // TMS 1 -> IR_update
//     IR_pause,
//         // TMS 0 -> IR_pause
//         // TMS 1 -> IR_exit2
//     IR_exit2,
//         // TMS 0 -> IR_shift
//         // TMS 1 -> IR_update
//     IR_update,
//         // TMS 0 -> idle
//         // TMS 1 -> DR_select
// };

// pub fn Adapter(comptime config: Config) type { comptime {

//     var pad_ids: []const PadID = &[_]PadID {
//         config.tck,
//         config.tms,
//         config.tdo,
//         config.tdi,
//     };

//     return struct {
//         const Self = @This();
//         current_state: State,
//         target_state: State,
//         next_state: State,

//         pub fn init() Self {
//             const cs = microbe.interrupts.enterCriticalSection();
//             defer cs.leave();

//             microbe.pads.reserve(pad_ids, pad_reservation_name);
//             chip.gpio.ensurePortsEnabled(pad_ids);
//             chip.gpio.configureTermination(pad_ids, config.termination);
//             switch (config.mode) {
//                 .output => {
//                     chip.gpio.configureSlewRate(pad_ids, config.slew);
//                     chip.gpio.configureDriveMode(pad_ids, config.drive);
//                     chip.gpio.configureAsOutput(pad_ids);
//                 },
//                 .input => {
//                     chip.gpio.configureAsInput(pad_ids);
//                 },
//                 .bidirectional => {
//                     chip.gpio.configureSlewRate(pad_ids, config.slew);
//                     chip.gpio.configureDriveMode(pad_ids, config.drive);
//                     chip.gpio.configureAsInput(pad_ids);
//                 },
//             }
//             return .{};
//         }

//         pub fn deinit(_: Self) void {
//             const cs = microbe.interrupts.enterCriticalSection();
//             defer cs.leave();

//             if (config.termination != .float) {
//                 chip.gpio.configureTermination(pad_ids, .float);
//             }
//             chip.gpio.configureAsUnused(pad_ids);
//             microbe.pads.release(pad_ids, pad_reservation_name);
//         }

//         pub fn read(_: Self) State {
//             var raw = RawInt {};
//             if (@hasDecl(chip.gpio, "readInputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
//                 inline for (chip.gpio.getIOPorts(pad_ids)) |port| {
//                     const port_state = chip.gpio.readInputPort(port);
//                     inline for (pad_ids) |pad, raw_bit| {
//                         if (chip.gpio.getIOPort(pad) == port) {
//                             const port_bit = 1 << chip.gpio.getOffset(pad);
//                             if (0 != (port_state & port_bit)) {
//                                 raw |= 1 << raw_bit;
//                             }
//                         }
//                     }
//                 }
//             } else {
//                 // TODO
//                 @compileError("not implemented!");
//             }
//             return @bitCast(State, raw);
//         }


//     };
// }}
