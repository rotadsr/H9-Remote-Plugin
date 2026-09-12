import Foundation

/// State machine for a "Check Connection" hardware-detection action, shared
/// by both the standalone app and the AU extension's UI.
public enum H9ConnectionCheckStatus: Equatable {
    case unknown
    case checking
    case detected
    case notDetected
}

/// Determines whether an incoming SysEx message counts as proof the physical
/// H9 is connected and responding — not just "a MIDI port exists," but "the
/// pedal replied with a checksum-valid program dump."
public enum H9DeviceDetection {
    /// - Parameters:
    ///   - bytes: a complete SysEx message (including F0/F7 framing).
    ///   - sysexID: the sysex ID this app/plugin instance is configured to
    ///     talk to; a reply framed for a different ID does not count.
    public static func isDetectionResponse(_ bytes: [UInt8], sysexID: UInt8) -> Bool {
        guard case .programDumpPayload(let payload) = H9SysExCodec.parse(bytes, expectedSysexID: sysexID) else {
            return false
        }
        let text = String(decoding: payload, as: UTF8.self)
        return (try? H9ProgramDump.parse(text: text)) != nil
    }
}
