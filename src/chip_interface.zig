const chip = @import("chip");

pub const PadID = chip.PadID;

pub const interrupts = struct {
    const i = chip.interrupts;

    pub const Interrupt = i.Interrupt;
    pub const Exception = i.Exception;
    pub const Handler = i.Handler;

    pub const unhandled = i.unhandled; // (comptime Exception) -> Handler

    pub const isEnabled = i.isEnabled; // (comptime Interrupt) -> bool
    pub const setEnabled = i.setEnabled; // (comptime Interrupt, comptime bool) -> void
    pub const configureEnables = i.configureEnables; // (comptime anytype) -> void
    pub const getPriority = i.getPriority; // (comptime Exception) -> u8
    pub const setPriority = i.setPriority; // (comptime Exception, u8) -> void
    pub const configurePriorities = i.configurePriorities; // (comptime anytype) -> void
    pub const isPending = i.isPending; // (comptime Exception) -> bool
    pub const setPending = i.setPending; // (comptime Exception, comptime bool) -> void
    pub const areGloballyEnabled = i.areGloballyEnabled; // () -> bool
    pub const setGloballyEnabled = i.setGloballyEnabled; // (bool) -> void
    pub const currentException = i.currentException; // () -> Exception
    pub const isInHandler = i.isInHandler; // () -> bool
    pub const waitForInterrupt = i.waitForInterrupt; // () -> void
    pub const waitForEvent = i.waitForEvent; // () -> void
    pub const sendEvent = i.sendEvent; // () -> void
};

pub const gpio = struct {
    const i = chip.gpio;

    pub const PortID = i.PortID;
    pub const PortDataType = i.PortDataType; // typically u16 or u32
    pub const getPort = i.getPort; //  (comptime PadID) -> PortID
    pub const getPorts = i.getPorts; // (comptime []const PadID) -> []const PortID
    pub const getOffset = i.getOffset; // (comptime PadID) -> comptime_int
    pub const getPadsInPort = i.getPadsInPort; // (comptime []const PadID, comptime PortID, comptime_int, comptime_int) -> []const PadID

    pub const ensureInit = i.ensureInit; // (comptime []const PadID) -> void
    pub const Config = i.Config; // struct containing slew rate, pull up/down, etc.
    pub const configure = i.configure; // (comptime []const PadID, Config) -> void

    pub const readInputPort = i.readInputPort; // (comptime PortID) -> PortDataType

    pub const readOutputPort = i.readOutputPort; // (comptime PortID) -> PortDataType
    pub const writeOutputPort = i.writeOutputPort; // (comptime PortID, PortDataType) -> void
    pub const clearOutputPortBits = i.clearOutputPortBits; // (comptime PortID, clear: PortDataType) -> void
    pub const setOutputPortBits = i.setOutputPortBits; // (comptime PortID, set: PortDataType) -> void
    pub const modifyOutputPort = i.modifyOutputPort; // (comptime PortID, clear: PortDataType, set: PortDataType) -> void

    pub const readOutputPortEnables = i.readOutputPortEnables; // (comptime PortID) -> PortDataType
    pub const writeOutputPortEnables = i.writeOutputPortEnables; // (comptime PortID) -> PortDataType
    pub const clearOutputPortEnableBits = i.clearOutputPortEnableBits; // (comptime PortID, clear: PortDataType) -> void
    pub const setOutputPortEnableBits = i.setOutputPortEnableBits; // (comptime PortID, set: PortDataType) -> void
    pub const modifyOutputPortEnables = i.modifyOutputPortEnables; // (comptime PortID, clear: PortDataType, set: PortDataType) -> void

    pub const readInput = i.readInput; // (comptime PadID) -> u1

    pub const readOutput = i.readOutput; // (comptime PadID) -> u1
    pub const writeOutput = i.writeOutput; // (comptime PadID, u1) -> void

    pub const readOutputEnable = i.readOutputEnable; // (comptime PadID) -> u1
    pub const writeOutputEnable = i.writeOutputEnable; // (comptime PadID, u1) -> void
    pub const setOutputEnables = i.setOutputEnables; // (comptime []const PadID) -> void
    pub const clearOutputEnables = i.clearOutputEnables; // (comptime []const PadID) -> void

};

pub const validation = struct {
    const i = chip.validation;
    pub const pads = i.pads; // ComptimeResourceValidator(PadID)
};

pub const timing = struct {
    const i = chip.timing;

    pub const currentTick = i.currentTick;
    pub const blockUntilTick = i.blockUntilTick;
    pub const getTickFrequencyHz = i.getTickFrequencyHz;

    pub const currentMicrotick = i.currentMicrotick;
    pub const blockUntilMicrotick = i.blockUntilMicrotick;
    pub const getMicrotickFrequencyHz = i.getMicrotickFrequencyHz;
};

pub const clocks = struct {
    const i = chip.clocks;

    pub const Config = i.Config;
    pub const ParsedConfig = i.ParsedConfig;
    pub const getConfig = i.getConfig;
    pub const applyConfig = i.applyConfig;
};
