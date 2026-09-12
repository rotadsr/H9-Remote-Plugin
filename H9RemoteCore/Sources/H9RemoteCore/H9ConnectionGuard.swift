import Foundation

/// Reproduces the Max patch's multi-instance mutual-exclusion guard
/// (`v/r ---local_enable_state`, `s/r ---connection_status`): when more than
/// one plugin instance is pointed at the same physical H9, only one instance
/// should be "enabled" (allowed to transmit CC/SysEx) at a time, so that two
/// instances don't fight over the hardware's state.
///
/// This is a pure state machine — the AUv3 layer is responsible for wiring
/// its notifications (e.g. a shared `DistributedNotificationCenter` or
/// app-group-scoped store keyed by `sysexID`) to `receiveExternalEnable`.
public final class H9ConnectionGuard {
    public enum ConnectionStatus: Equatable {
        case disconnected
        case enabledLocally
        case disabledBySibling
    }

    public private(set) var status: ConnectionStatus = .disconnected
    public private(set) var isLocallyEnabled: Bool = true

    public init() {}

    /// Call when the user (or default state) sets this instance's local
    /// enable toggle.
    public func setLocalEnable(_ enabled: Bool) {
        isLocallyEnabled = enabled
        status = enabled ? .enabledLocally : .disabledBySibling
    }

    /// Call when another instance sharing the same H9 announces it has taken
    /// control (mirrors the original device's cross-instance "Enable this
    /// instance to switch the pedal to these settings" hand-off message).
    public func receiveExternalEnable(fromSiblingEnabled siblingEnabled: Bool) {
        guard siblingEnabled else { return }
        isLocallyEnabled = false
        status = .disabledBySibling
    }

    /// Whether this instance is currently allowed to transmit CC/SysEx to
    /// the hardware.
    public var canTransmit: Bool {
        isLocallyEnabled
    }
}
