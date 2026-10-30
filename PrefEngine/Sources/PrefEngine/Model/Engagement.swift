import Foundation

/// Port of monetization/Engagement.kt: what the app remembers about the player
/// for ads and review prompts.
public final class EngagementState: Codable {
    /// single-player deals finished on this device, ever
    public var dealsFinished: Int = 0
    /// the player tapped Rate (the store cannot tell us whether a review followed)
    public var rated: Bool = false
    /// "Remove ads" is owned; confirmed by the store, remembered for offline starts
    public var adFree: Bool = false

    public init() {}
}

/// Kept in one small file; every call reads it fresh, so there is no stale copy.
public enum Engagement {
    /// A new player's first deals are free of ads.
    public static let freeDeals = 10
    /// The rate banner returns after this many finished deals until the player rates.
    public static let rateEvery = 10

    private static let file = "engagement.json"

    public static func state() -> EngagementState {
        guard let text = PrefStorage.readText(file),
              let s = try? PrefStorage.decodeFromString(EngagementState.self, text) else {
            return EngagementState()
        }
        return s
    }

    private static func save(_ s: EngagementState) {
        PrefStorage.writeText(file, PrefStorage.encodeToString(s))
    }

    public static var adFree: Bool { state().adFree }

    public static func setAdFree(_ owned: Bool) {
        let s = state()
        if s.adFree != owned {
            s.adFree = owned
            save(s)
        }
    }

    public static func markRated() {
        let s = state()
        if !s.rated {
            s.rated = true
            save(s)
        }
    }

    /// A single-player deal just ended; returns how many have ended in total.
    public static func dealFinished() -> Int {
        let s = state()
        s.dealsFinished += 1
        save(s)
        return s.dealsFinished
    }

    /// The rate banner is due at every `rateEvery`th finished deal, until the player rates.
    public static func rateBannerDue(_ s: EngagementState = state()) -> Bool {
        !s.rated && s.dealsFinished > 0 && s.dealsFinished % rateEvery == 0
    }
}

/// The rules deciding whether the end of a deal shows an interstitial.
public enum AdPolicy {
    /// Never show two ads closer together than this, whatever the deal count.
    public static let minGapMs: Int64 = 45_000

    /// - dealsFinished: the deal that has just ended, counted from one
    /// - msSinceLastAd: time since the previous interstitial closed
    public static func shouldShow(
        adsEnabled: Bool,
        adFree: Bool,
        dealsFinished: Int,
        adReady: Bool,
        msSinceLastAd: Int64
    ) -> Bool {
        adsEnabled && !adFree && adReady &&
            dealsFinished > Engagement.freeDeals &&
            msSinceLastAd >= minGapMs
    }
}
