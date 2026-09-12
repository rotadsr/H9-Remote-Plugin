import CoreMIDI
import Foundation
import H9RemoteCore

/// Thin CoreMIDI wrapper giving the standalone app direct hardware MIDI I/O
/// to the H9 — unlike the AUv3 extension, this app is not sandboxed to the
/// host's MIDI event list, so it can open real CoreMIDI ports.
final class H9MIDIConnection: ObservableObject {
    struct Endpoint: Identifiable, Hashable {
        let id: MIDIUniqueID
        let ref: MIDIEndpointRef
        let name: String
    }

    @Published private(set) var sources: [Endpoint] = []
    @Published private(set) var destinations: [Endpoint] = []
    @Published var selectedSourceID: MIDIUniqueID? {
        didSet { persistSelection() }
    }
    @Published var selectedDestinationID: MIDIUniqueID? {
        didSet { persistSelection() }
    }

    /// Called with each complete, reassembled SysEx message or 3-byte CC
    /// message received from the selected source.
    var onMessageReceived: (([UInt8]) -> Void)?

    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var inputPort = MIDIPortRef()
    private var sysExBuffer: [UInt8] = []

    private static let sourceDefaultsKey = "H9Remote.selectedSourceID"
    private static let destinationDefaultsKey = "H9Remote.selectedDestinationID"

    init() {
        setUpClient()
        refreshEndpoints()
        restoreSelection()
    }

    deinit {
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }

    private func setUpClient() {
        MIDIClientCreateWithBlock("H9Remote" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshEndpoints() }
        }
        MIDIOutputPortCreate(client, "H9Remote Output" as CFString, &outputPort)
        MIDIInputPortCreateWithBlock(client, "H9Remote Input" as CFString, &inputPort) { [weak self] packetList, _ in
            self?.handleIncoming(packetList)
        }
        if let source = selectedSourceEndpoint {
            MIDIPortConnectSource(inputPort, source.ref, nil)
        }
    }

    // MARK: - Endpoint enumeration

    func refreshEndpoints() {
        sources = (0..<MIDIGetNumberOfSources()).compactMap { index in
            Self.endpoint(from: MIDIGetSource(index))
        }
        destinations = (0..<MIDIGetNumberOfDestinations()).compactMap { index in
            Self.endpoint(from: MIDIGetDestination(index))
        }
    }

    private static func endpoint(from ref: MIDIEndpointRef) -> Endpoint? {
        guard ref != 0 else { return nil }
        var uniqueID: MIDIUniqueID = 0
        MIDIObjectGetIntegerProperty(ref, kMIDIPropertyUniqueID, &uniqueID)
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(ref, kMIDIPropertyDisplayName, &name)
        let displayName = name?.takeRetainedValue() as String? ?? "Unknown"
        return Endpoint(id: uniqueID, ref: ref, name: displayName)
    }

    private var selectedSourceEndpoint: Endpoint? {
        sources.first { $0.id == selectedSourceID }
    }

    private var selectedDestinationEndpoint: Endpoint? {
        destinations.first { $0.id == selectedDestinationID }
    }

    func selectSource(_ endpoint: Endpoint?) {
        if let previous = selectedSourceEndpoint {
            MIDIPortDisconnectSource(inputPort, previous.ref)
        }
        selectedSourceID = endpoint?.id
        if let endpoint {
            MIDIPortConnectSource(inputPort, endpoint.ref, nil)
        }
    }

    func selectDestination(_ endpoint: Endpoint?) {
        selectedDestinationID = endpoint?.id
    }

    // MARK: - Sending

    /// Sends raw MIDI bytes (a 3-byte CC message or a complete SysEx
    /// message) to the selected destination.
    ///
    /// `MIDIPacketList` is a C variable-length struct — a bare
    /// `MIDIPacketList()` only has stack space for its fixed header plus one
    /// `MIDIPacket`'s worst-case fixed-size `data` field, but
    /// `MIDIPacketListAdd` was previously told the buffer was a flat 1024
    /// bytes regardless of how much space actually existed. Short 3-byte CC
    /// messages happened to fit and never tripped the stack-protector, but a
    /// full SysEx program dump (hundreds of bytes) overflowed the real
    /// on-stack allocation and crashed with SIGABRT ("stack buffer
    /// overflow") — exactly the crash hit when "Save Preset" sent a full
    /// dump. Fixed by heap-allocating a buffer sized for what's actually
    /// being sent and telling `MIDIPacketListAdd` the truth about its size.
    func send(_ bytes: [UInt8]) {
        guard let destination = selectedDestinationEndpoint, !bytes.isEmpty else { return }
        let bufferSize = MemoryLayout<MIDIPacketList>.size + bytes.count
        let rawPacketList = UnsafeMutableRawPointer.allocate(
            byteCount: bufferSize,
            alignment: MemoryLayout<MIDIPacketList>.alignment
        )
        defer { rawPacketList.deallocate() }
        let packetList = rawPacketList.assumingMemoryBound(to: MIDIPacketList.self)

        let packet = MIDIPacketListInit(packetList)
        bytes.withUnsafeBufferPointer { buffer in
            _ = MIDIPacketListAdd(packetList, bufferSize, packet, 0, buffer.count, buffer.baseAddress!)
        }
        MIDISend(outputPort, destination.ref, packetList)
    }

    // MARK: - Receiving

    private func handleIncoming(_ packetList: UnsafePointer<MIDIPacketList>) {
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            let length = Int(packet.length)
            let bytes = withUnsafeBytes(of: packet.data) { rawBuffer in
                Array(rawBuffer.prefix(length))
            }
            process(bytes)
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func process(_ rawBytes: [UInt8]) {
        // System Realtime messages (Timing Clock 0xF8, Start/Continue/Stop,
        // Active Sensing, Reset) are single status bytes that can appear
        // interleaved anywhere in the stream, including mid-SysEx — the H9
        // sends Active Sensing/Clock continuously. Strip them before any
        // other parsing so they don't corrupt the SysEx buffer or the CC
        // triple below.
        let bytes = rawBytes.filter { !(0xF8...0xFF).contains($0) }

        for byte in bytes {
            if byte == H9SysExCodec.sysExStart {
                sysExBuffer = [byte]
            } else if !sysExBuffer.isEmpty {
                sysExBuffer.append(byte)
                if byte == H9SysExCodec.sysExEnd {
                    let complete = sysExBuffer
                    sysExBuffer = []
                    DispatchQueue.main.async { [weak self] in self?.onMessageReceived?(complete) }
                }
            }
        }
        // Non-SysEx (CC) messages arrive as a complete 3-byte packet with no
        // 0xF0/0xF7 framing; forward them directly when we're not mid-SysEx.
        if sysExBuffer.isEmpty, bytes.count == 3, bytes[0] & 0xF0 == 0xB0 {
            DispatchQueue.main.async { [weak self] in self?.onMessageReceived?(bytes) }
        }
    }

    // MARK: - Persistence

    private func persistSelection() {
        let defaults = UserDefaults.standard
        if let sourceID = selectedSourceID {
            defaults.set(Int32(sourceID), forKey: Self.sourceDefaultsKey)
        }
        if let destinationID = selectedDestinationID {
            defaults.set(Int32(destinationID), forKey: Self.destinationDefaultsKey)
        }
    }

    private func restoreSelection() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.sourceDefaultsKey) != nil {
            let storedID = MIDIUniqueID(defaults.integer(forKey: Self.sourceDefaultsKey))
            if let endpoint = sources.first(where: { $0.id == storedID }) {
                selectSource(endpoint)
            }
        }
        if defaults.object(forKey: Self.destinationDefaultsKey) != nil {
            let storedID = MIDIUniqueID(defaults.integer(forKey: Self.destinationDefaultsKey))
            if let endpoint = destinations.first(where: { $0.id == storedID }) {
                selectDestination(endpoint)
            }
        }
    }
}
