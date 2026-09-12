import Foundation

/// Builds and parses the H9's SysEx envelope, per Eventide's own
/// "MIDI Sysex Messages for the Eventide Factor series pedals" spec
/// (TJsysex.doc, njr 3/20/2008):
///
/// `F0 <manufacturerID> <familyByte> <id> <messageCode> <data...> F7`
///
/// `0x1C` is Eventide's registered MIDI manufacturer ID; `0x70` (112) is the
/// product-family byte. Every message — request or reply — carries its own
/// one-byte message code right after `<id>`; a reply's code is **not** the
/// same byte as the request that solicited it (e.g. `SYSEXC_TJ_PROGRAM_WANT`
/// = `0x4E` requests a dump, but the reply itself is tagged
/// `SYSEXC_TJ_PROGRAM_DUMP` = `0x4F`, followed by the ASCII payload).
public enum H9SysExCodec {
    public static let manufacturerID: UInt8 = 0x1C
    public static let familyByte: UInt8 = 0x70

    /// SYSEXC_TJ_PROGRAM_WANT — request the current preset; unit replies
    /// with `programDumpCode`.
    public static let getCurrentPresetCommand: UInt8 = 0x4E
    /// SYSEXC_TJ_PROGRAM_DUMP — the current-preset reply/push message code.
    public static let programDumpCode: UInt8 = 0x4F
    /// SYSEXC_TJ_PRESETS_WANT — request a dump of all presets; unit replies
    /// with `presetsDumpCode`.
    public static let dumpAllPresetsCommand: UInt8 = 0x48
    /// SYSEXC_TJ_PRESETS_DUMP — the all-presets reply message code.
    public static let presetsDumpCode: UInt8 = 0x49

    public static let sysExStart: UInt8 = 0xF0
    public static let sysExEnd: UInt8 = 0xF7

    /// Builds a "get current preset" request message.
    public static func getCurrentPresetRequest(sysexID: UInt8) -> [UInt8] {
        [sysExStart, manufacturerID, familyByte, sysexID, getCurrentPresetCommand, sysExEnd]
    }

    /// Builds a "dump all presets" request message.
    public static func dumpAllPresetsRequest(sysexID: UInt8) -> [UInt8] {
        [sysExStart, manufacturerID, familyByte, sysexID, dumpAllPresetsCommand, sysExEnd]
    }

    /// Wraps a program-dump payload (ASCII bytes) in the SysEx envelope,
    /// tagged with `programDumpCode`, for transmission to the hardware
    /// (used both to push a preset and as the shape of the unit's reply).
    public static func wrapProgramDump(_ payloadBytes: [UInt8], sysexID: UInt8) -> [UInt8] {
        [sysExStart, manufacturerID, familyByte, sysexID, programDumpCode] + payloadBytes + [sysExEnd]
    }

    public enum ParsedMessage: Equatable {
        case getCurrentPresetRequest
        case dumpAllPresetsRequest
        case programDumpPayload([UInt8])
        case presetsDumpPayload([UInt8])
        case unrecognized
    }

    /// Parses a complete SysEx message (including F0/F7 framing), returning
    /// the manufacturer/family/id-checked payload classification. Returns
    /// `.unrecognized` for any message that doesn't match the H9's envelope.
    public static func parse(_ message: [UInt8], expectedSysexID: UInt8) -> ParsedMessage {
        guard message.count >= 6,
              message.first == sysExStart,
              message.last == sysExEnd,
              message[1] == manufacturerID,
              message[2] == familyByte,
              message[3] == expectedSysexID
        else { return .unrecognized }

        let messageCode = message[4]
        let data = Array(message[5..<(message.count - 1)])

        switch (messageCode, data.isEmpty) {
        case (getCurrentPresetCommand, true):
            return .getCurrentPresetRequest
        case (dumpAllPresetsCommand, true):
            return .dumpAllPresetsRequest
        case (programDumpCode, _):
            return .programDumpPayload(data)
        case (presetsDumpCode, _):
            return .presetsDumpPayload(data)
        default:
            return .unrecognized
        }
    }
}
