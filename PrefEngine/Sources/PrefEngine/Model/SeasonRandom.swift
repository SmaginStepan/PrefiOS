import Foundation
import CryptoKit

/// Source of the random numbers behind deals and bot decisions.
/// Mirrors Android's PrefRandom interface.
public protocol PrefRandom {
    func nextInt(_ bound: Int) -> Int
    func nextDouble() -> Double
}

/// Ordinary games: the platform generator.
public struct DefaultRandom: PrefRandom {
    public init() {}

    public func nextInt(_ bound: Int) -> Int {
        bound > 0 ? Int.random(in: 0..<bound) : 0
    }

    public func nextDouble() -> Double {
        Double.random(in: 0..<1)
    }
}

/// The season generator. Every season player must get the same deals, so this
/// is specified exactly, bit for bit, and reproduced identically on every
/// platform (this file is a literal port of Android's SeasonRandom.kt):
///
///  - stream seed: SHA-256 of the UTF-8 text "<seedHex>|<purpose>|<index>",
///    first 8 bytes read big-endian as an unsigned 64-bit state;
///  - purposes: "deal" (index = deal number), "bots" (index = deal number),
///    "config" (index = 0);
///  - next(): SplitMix64 — state += 0x9E3779B97F4A7C15;
///    z = state; z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
///    z = (z ^ (z >> 27)) * 0x94D049BB133111EB; return z ^ (z >> 31);
///    all arithmetic is unsigned 64-bit, wrapping, shifts are logical;
///  - nextInt(bound) = (next() >> 1) % bound;
///  - nextDouble() = (next() >> 11) * 2^-53.
///
/// A reference type, like the Kotlin class: the game and every AI call site
/// share ONE stream, so the order of draws is part of the contract.
public final class SeasonRandom: PrefRandom, Codable {
    public var state: UInt64

    public init(state: UInt64 = 0) {
        self.state = state
    }

    private func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public func nextInt(_ bound: Int) -> Int {
        bound > 0 ? Int((next() >> 1) % UInt64(bound)) : 0
    }

    public func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    public static func forPurpose(_ seedHex: String, _ purpose: String, _ index: Int) -> SeasonRandom {
        let digest = SHA256.hash(data: Data("\(seedHex)|\(purpose)|\(index)".utf8))
        var state: UInt64 = 0
        for byte in digest.prefix(8) {
            state = (state << 8) | UInt64(byte) // big-endian
        }
        return SeasonRandom(state: state)
    }

    // Persisted like Kotlin's `var state: Long`: a signed 64-bit JSON number
    // holding the same bit pattern.
    private enum CodingKeys: String, CodingKey {
        case state
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let signed = try c.decodeIfPresent(Int64.self, forKey: .state) ?? 0
        state = UInt64(bitPattern: signed)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Int64(bitPattern: state), forKey: .state)
    }
}
