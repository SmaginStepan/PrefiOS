import Foundation

/// Builds per-viewer snapshots of a hosted game. Seats are ROTATED so every
/// viewer sees themselves as seat 0 (bottom of the table), and REDACTED so a
/// hand is face-up only for its owner or when the play has opened it.
public enum RemoteViews {

    public static func rot(_ seat: Int, _ viewer: Int) -> Int {
        (seat - viewer + 3) % 3
    }

    /// Port of TableLayout.computeField from one viewer's perspective.
    public static func buildFieldFor(_ game: Game, _ viewer: Int) -> [PlacedCard] {
        var res: [PlacedCard] = []
        let deal = game.deal

        for hand in 0..<3 {
            let faceUp = hand == viewer || deal.hands[hand].isVisible
            res.append(contentsOf: TableLayout.handPlacements(
                deal.hands[hand].cards,
                rot(hand, viewer),
                special: false,
                hidden: !faceUp
            ))
        }

        for (key, card) in deal.inPlay.entries {
            let relKey = key < 0 ? key : rot(key, viewer)
            let c = TableLayout.inPlayCoords(relKey)
            res.append(PlacedCard(card: card, hand: relKey, x: c.0, y: c.1, isInPlay: true))
        }

        if deal.prikup.isVisible {
            var k = 0
            for card in deal.prikup.cards {
                let x = (TableLayout.W / 2) - TableLayout.S1 / 1.36 + Double(k) * TableLayout.S1 / 1.36
                let y = (TableLayout.H / 2) - (TableLayout.S1 / 2)
                res.append(PlacedCard(card: card, hand: 3, x: x, y: y, isPrikup: true))
                k += 1
            }
        }
        return res
    }

    private static func rotResult(_ r: Calculation.GameResult, _ viewer: Int) -> Calculation.GameResult {
        let out = Calculation.GameResult()
        out.gameType = r.gameType
        out.dealer = rot(r.dealer, viewer)
        out.contractor = rot(r.contractor, viewer)
        out.contract = r.contract
        for (k, v) in r.taken.entries {
            out.taken[rot(k, viewer)] = v
        }
        out.visters = r.visters.map { rot($0, viewer) }
        out.multiplier = r.multiplier
        out.halfWithDealer = r.halfWithDealer
        return out
    }

    /// Port of GameViewModel.buildTableInfo from one viewer's perspective.
    public static func buildTableInfoFor(_ game: Game, _ viewer: Int) -> TableInfo {
        func rotList<T>(_ src: [T]) -> [T] {
            (0..<3).map { rel in src[(rel + viewer) % 3] }
        }
        var info = TableInfo()
        info.phase = game.phase
        info.names = rotList(game.calc.scores.map { $0.name })
        info.dealer = rot(game.calc.dealer, viewer)
        info.taken = rotList(game.deal.hands.map { $0.taken })
        info.currentGameType = game.currentGameType
        info.contractor = rot(game.contractor, viewer)
        var isVister = OrderedIntDict<Bool>()
        for (k, v) in game.isVister.entries {
            isVister[rot(k, viewer)] = v
        }
        info.isVister = isVister
        var curentBids = OrderedIntDict<Game.Bid>()
        for (k, v) in game.curentBids.entries {
            curentBids[rot(k, viewer)] = v
        }
        info.curentBids = curentBids
        info.maxBid = game.maxBid
        info.playerToTake = rot(game.playerToTake, viewer)
        info.playerInTurn = rot(game.playerInTurn, viewer)
        info.gameResult = game.phase == .EndPlay ? rotResult(game.getGameResult(), viewer) : nil
        info.showPrikupBtn1 = false
        info.showPrikupBtn2 = false
        info.showTricksBtn = game.phase == .Playing || game.phase == .EndTurn
        return info
    }

    /// Score standing rotated for one viewer (whists as the written sum).
    public static func buildScoresFor(_ game: Game, _ viewer: Int) -> ScoreSnap {
        func idx(_ rel: Int) -> Int {
            (rel + viewer) % 3
        }
        let sc = game.calc.scores
        return ScoreSnap(
            names: (0..<3).map { sc[idx($0)].name },
            pulya: (0..<3).map { sc[idx($0)].pulya },
            gora: (0..<3).map { sc[idx($0)].gora },
            whists: (0..<3).map { i in sc[idx(i)].visty.values.reduce(0, +) },
            limit: game.calc.limit
        )
    }

    /// What the current actor must answer, by phase.
    public static func buildAsk(_ game: Game) -> Ask {
        switch game.phase {
        case .Negotiations: return Ask("bid", bids: game.getAllowedBids())
        case .GameChoose: return Ask("contract", bids: game.getAllowedBids())
        case .VistNegotiations: return Ask("vist")
        case .OpeningChoose: return Ask("opening")
        case .Discarding: return Ask("discard")
        case .Playing: return Ask("play", allowed: game.getAllowedMoves())
        default: return Ask("confirm") // PrikupOpened, EndTurn, EndPlay, ScoreView
        }
    }
}
