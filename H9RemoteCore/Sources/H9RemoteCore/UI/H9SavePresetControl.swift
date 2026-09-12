import SwiftUI

/// Sends the current state tagged with a target preset slot number.
///
/// **This is unverified as an actual permanent write.** Live-tested against
/// a real H9 Pedal: pulling the current preset (preset 97), re-sending it
/// tagged as preset 99 with a changed name, then re-querying "current
/// preset" still reported preset number 97 — the name changed in the live/
/// temporary buffer, but nothing indicates preset slot 99 was ever actually
/// written. `SYSEXC_TJ_PRESETS_WANT` (dump-all-presets) also produced no
/// SysEx reply at all in the same test. Eventide's own H9 Control manual
/// states saving requires an **explicit** separate action ("Save" / "Save
/// to Device" button) — i.e. loading a preset (even tagged with a different
/// slot number) is documented as NOT the same operation as saving it, and
/// no separate commit/write SysEx message has been found in Eventide's
/// technote, the original Max device this AU was ported from, or this
/// project's own research. It's possible real non-volatile writes only
/// happen over Eventide's proprietary encrypted Bluetooth channel (used by
/// their own H9 Control app), meaning permanent preset writes may not be
/// achievable over plain MIDI SysEx at all. Until that's resolved, this
/// control is kept honest about that uncertainty rather than promising a
/// working "save."
public struct H9SavePresetControl: View {
    @Binding private var slot: Int
    private let onSave: (Int) -> Void
    @State private var showConfirmation = false

    public init(slot: Binding<Int>, onSave: @escaping (Int) -> Void) {
        self._slot = slot
        self.onSave = onSave
    }

    public var body: some View {
        HStack(spacing: 8) {
            Stepper(value: $slot, in: 1...99) {
                Text("Slot \(slot)")
                    .monospacedDigit()
                    .frame(minWidth: 56, alignment: .leading)
            }
            Button {
                showConfirmation = true
            } label: {
                Label("Send Preset (unverified save)", systemImage: "square.and.arrow.down")
            }
        }
        .confirmationDialog(
            "Send preset tagged as slot \(slot)?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Send Anyway", role: .destructive) {
                onSave(slot)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This has not been confirmed to permanently save to slot \(slot) on the H9 — testing suggests it may only update the pedal's temporary buffer without actually writing to that slot. Eventide's own app may use a separate, undocumented channel for real saves. Proceed anyway?")
        }
    }
}

#Preview {
    H9SavePresetControl(slot: .constant(12)) { _ in }
        .padding()
}
