import Foundation

/// Kotlin's Double.roundToLong(): nearest integer, ties rounded toward
/// POSITIVE infinity (-42.5 -> -42, 42.5 -> 43). Swift's `.rounded()` rounds
/// ties away from zero (-42.5 -> -43), which would make a season total drift
/// from Android's on negative half-whist settlements.
public func roundToLongHalfUp(_ x: Double) -> Int64 {
    let f = x.rounded(.down)
    return Int64(x - f >= 0.5 ? f + 1 : f)
}
