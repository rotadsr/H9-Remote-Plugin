import SwiftUI

/// Each pedal lineage's real on-hardware UI/LED color, sourced directly from
/// the original Max device's own source data
/// (`github.com/malacalypse/h9-remote`, `data/ModuleData.txt`) — the same
/// RGB triples the physical pedal itself uses to color-code its display per
/// module, not an arbitrary UI choice.
public extension H9PedalLineage {
    var accentColor: Color {
        switch self {
        case .timeFactor: return Color(red: 50 / 255, green: 64 / 255, blue: 188 / 255)
        case .modFactor: return Color(red: 11 / 255, green: 93 / 255, blue: 24 / 255)
        case .pitchFactor: return Color(red: 191 / 255, green: 36 / 255, blue: 1 / 255)
        case .space: return Color(red: 42 / 255, green: 43 / 255, blue: 53 / 255)
        case .h9New: return Color(red: 176 / 255, green: 177 / 255, blue: 177 / 255)
        }
    }

    /// A contrast-safe variant of `accentColor` for use on the app's dark
    /// control surface. `accentColor` is the pedal's real hardware LED
    /// color (kept as-is for the algorithm picker's small swatch), but
    /// Space's near-black and H9-new's flat grey are both too low-contrast
    /// to use as a knob's fill/indicator color against a dark background.
    var knobAccentColor: Color {
        switch self {
        case .space: return Color(red: 120 / 255, green: 130 / 255, blue: 255 / 255) // bright blue-violet, same hue family as its dark base color
        case .h9New: return Color(red: 230 / 255, green: 230 / 255, blue: 235 / 255) // bright near-white instead of flat mid-grey
        default: return accentColor // TimeFactor/ModFactor/PitchFactor's real colors already contrast fine
        }
    }
}
