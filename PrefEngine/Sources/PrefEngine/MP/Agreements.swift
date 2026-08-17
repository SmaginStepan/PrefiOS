import Foundation

/// Agreement («расписать») rules shared by the host, guests and single player.
///
/// All functions here work in the VIEWER-RELATIVE frame of a `TableInfo`
/// (seat 0 = the viewer), which is identical to the absolute frame on the
/// host/single-player table.
public enum Agreements {

    /// May this viewer open the offer menu right now?
    public static func canOffer(_ info: TableInfo) -> Bool {
        if info.phase != .Playing { return false }
        switch info.currentGameType {
        case .Miser:
            return !info.watching // any of the three players; the sitting dealer only responds
        case .Normal:
            let whisters = Set(info.isVister.entries.filter { $0.value }.map { $0.key })
            if whisters.isEmpty { return false } // nobody to agree with
            return !info.watching && (info.contractor == 0 || whisters.contains(0))
        default:
            return false
        }
    }

    /// Remaining (unresolved) tricks; the unfinished trick counts as remaining.
    private static func remaining(_ info: TableInfo) -> Int {
        10 - info.taken.reduce(0, +)
    }

    /// Step 1: possible final trick counts for the declarer.
    /// Normal games: contract-3 .. 10 clipped to what is still reachable and
    /// to what the other hands' current takes allow. Misère: 1..3.
    public static func declarerOptions(_ info: TableInfo) -> [Int] {
        let c = info.contractor
        let tC = info.taken.indices.contains(c) ? info.taken[c] : 0
        let r = remaining(info)
        let othersTaken = info.taken.reduce(0, +) - tC
        if info.currentGameType == .Miser {
            return (1...3).filter { $0 >= tC && $0 <= tC + r }
        }
        guard let contract = info.maxBid?.contract else { return [] }
        let low = max(contract - 3, 0)
        if low > 10 { return [] }
        return (low...10).filter { n in
            n >= tC && n <= tC + r && 10 - n >= othersTaken
        }
    }

    /// Whister seats (viewer-relative).
    public static func whisters(_ info: TableInfo) -> [Int] {
        info.isVister.entries.filter { $0.value }.map { $0.key }.sorted()
    }

    /// Step 2 (only with two whisters in a normal game): the possible final
    /// (first whister, second whister) splits for a given declarer count.
    public static func whistSplits(_ info: TableInfo, _ declarerTakes: Int) -> [(Int, Int)] {
        let w = whisters(info)
        if w.count != 2 { return [] }
        let (a, b) = (w[0], w[1])
        let tA = info.taken.indices.contains(a) ? info.taken[a] : 0
        let tB = info.taken.indices.contains(b) ? info.taken[b] : 0
        let r = remaining(info)
        let pool = 10 - declarerTakes
        return (tA...(tA + r)).compactMap { fa in
            let fb = pool - fa
            return (fb >= tB && fb <= tB + r) ? (fa, fb) : nil
        }
    }

    /// The full final-taken list (viewer-relative, 3 entries) for an offer.
    /// With one whister the passer keeps their current takes and the whister
    /// gets the rest; их судьбу решает вистующий.
    public static func buildTaken(_ info: TableInfo, _ declarerTakes: Int, split: (Int, Int)? = nil) -> [Int] {
        var res = info.taken
        let c = info.contractor
        res[c] = declarerTakes
        if info.currentGameType == .Miser {
            // catchers' individual counts don't affect miser scoring; hand the
            // remainder to the first catcher for a consistent total of 10
            let catchers = (0...2).filter { $0 != c }
            res[catchers[1]] = info.taken[catchers[1]]
            res[catchers[0]] = 10 - declarerTakes - res[catchers[1]]
        } else {
            let w = whisters(info)
            switch w.count {
            case 1:
                let passer = (0...2).first { $0 != c && $0 != w[0] }!
                res[passer] = info.taken[passer]
                res[w[0]] = 10 - declarerTakes - res[passer]
            case 2:
                guard let s = split else { return res }
                res[w[0]] = s.0
                res[w[1]] = s.1
            default:
                break
            }
        }
        return res
    }

    /// Is this the declarer's unilateral surrender («без 3, застрелиться»)?
    public static func isSurrender(_ info: TableInfo, offererRel: Int, declarerTakes: Int) -> Bool {
        if info.currentGameType != .Normal { return false }
        guard let contract = info.maxBid?.contract else { return false }
        return offererRel == info.contractor && declarerTakes == contract - 3
    }

    /// The conservative bot rule: accept only if the offer is at least as good
    /// as the bot's best possible outcome over ALL continuations (zero-sum:
    /// an opponent's gain counts as the bot's loss). Absolute game frame.
    public static func botAccepts(_ botSeat: Int, _ game: Game, _ finalTaken: [Int: Int]) -> Bool {
        let c = game.contractor
        guard let offered = finalTaken[c] else { return false }
        let tC = game.deal.hands[c].taken
        let r = 10 - game.deal.totalTaken
        if game.currentGameType == .Miser {
            return botSeat == c
                ? offered <= tC // best case: catches nothing more
                : offered >= tC + r // best case: the misère catches everything
        }
        if botSeat == c {
            return offered >= tC + r // best case: takes all the rest
        }
        guard let own = finalTaken[botSeat] else { return false }
        // best case for a whister: the declarer is stopped cold AND
        // the whister itself takes every remaining trick
        return offered <= tC && own >= game.deal.hands[botSeat].taken + r
    }
}
