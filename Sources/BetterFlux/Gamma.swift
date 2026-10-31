import CoreGraphics
import Foundation

/// Applies warmth and dimming to every display by scaling its gamma table.
/// The display's own ColorSync table is captured first so the calibration is preserved.
enum Gamma {
    private struct Table {
        var r: [CGGammaValue]
        var g: [CGGammaValue]
        var b: [CGGammaValue]
    }

    private static var originals: [CGDirectDisplayID: Table] = [:]

    static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// Reset to ColorSync settings and remember each display's untouched table.
    static func capture() {
        CGDisplayRestoreColorSyncSettings()
        originals = [:]
        for display in activeDisplays() {
            let capacity = CGDisplayGammaTableCapacity(display)
            guard capacity > 0 else { continue }
            var r = [CGGammaValue](repeating: 0, count: Int(capacity))
            var g = r, b = r
            var samples: UInt32 = 0
            guard CGGetDisplayTransferByTable(display, capacity, &r, &g, &b, &samples) == .success,
                  samples > 0 else { continue }
            let n = Int(samples)
            originals[display] = Table(r: Array(r.prefix(n)), g: Array(g.prefix(n)), b: Array(b.prefix(n)))
        }
    }

    /// Multiply each channel by the given factors (0...1).
    static func apply(red: Double, green: Double, blue: Double, brightness: Double) {
        let displays = activeDisplays()
        if displays.contains(where: { originals[$0] == nil }) {
            capture()
        }
        for display in displays {
            guard let t = originals[display] else { continue }
            let rs = CGGammaValue(red * brightness)
            let gs = CGGammaValue(green * brightness)
            let bs = CGGammaValue(blue * brightness)
            let r = t.r.map { $0 * rs }
            let g = t.g.map { $0 * gs }
            let b = t.b.map { $0 * bs }
            CGSetDisplayTransferByTable(display, UInt32(r.count), r, g, b)
        }
    }

    static func restore() {
        CGDisplayRestoreColorSyncSettings()
    }
}

enum ColorTemperature {
    /// Approximate RGB (0...1) for a black-body temperature, normalised so 6500K is white.
    static func rgb(kelvin: Double) -> (Double, Double, Double) {
        let raw = rawRGB(kelvin)
        let white = rawRGB(6500)
        return (min(1, raw.0 / white.0), min(1, raw.1 / white.1), min(1, raw.2 / white.2))
    }

    // Tanner Helland's curve fit.
    private static func rawRGB(_ kelvin: Double) -> (Double, Double, Double) {
        let t = kelvin / 100
        let r: Double = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let g: Double = t <= 66
            ? 99.4708025861 * log(t) - 161.1195681661
            : 288.1221695283 * pow(t - 60, -0.0755148492)
        let b: Double
        if t >= 66 { b = 255 } else if t <= 19 { b = 0 } else { b = 138.5177312231 * log(t - 10) - 305.0447927307 }
        func clamp(_ v: Double) -> Double { max(0, min(255, v)) }
        return (clamp(r), clamp(g), clamp(b))
    }
}
