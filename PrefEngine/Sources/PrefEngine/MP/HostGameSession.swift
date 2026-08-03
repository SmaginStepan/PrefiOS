import Foundation

public enum SeatKind {
    case local, bot, remote
}

/// Runs a hosted multiplayer game on top of the untouched engine.
///
/// The engine's isAI() is disabled via game.externalDriver, so game.next()
/// stops at EVERY input point; this class dispatches each stop to the seat's
/// driver: the local UI, the built-in AI, or a remote player over the relay.
///
/// Confirmation phases (opened prikup, finished trick, deal result, score
/// sheet) are handled as ORDER-INDEPENDENT stops: every human — including the
/// 4-player sitting dealer — confirms in any order; once a player confirmed,
/// their view moves on (trick hidden, score sheet dismissed) and shows who is
/// still being waited for. The engine's own turn-ordered confirm cycle is
/// applied in one go when the last human confirms. Only real moves (bids,
/// whist, discards, cards) stay with the seat that owns them.
///
/// 3 seats: `game` runs the whole match on `matchCalc` directly.
/// 4 seats: the dealer sits out; every deal is a fresh single-deal 3-player
/// game among the other three, and this session maps its seats onto the real
/// ones and writes each result into the authoritative 4-column `matchCalc`.
///
/// Single-threaded by design: the caller must serialize calls (the app runs
/// it on one queue; the unit test calls it directly).
public final class HostGameSession {

    private let seats: [SeatKind]
    private let names: [String]
    /// Authoritative pulka for the match; 3 or 4 columns matching `seats`.
    public let matchCalc: Calculation
    /// Deliver a state message to a REMOTE seat (absolute/real seat number).
    private let sendToSeat: (Int, GameMsg.State) -> Void
    /// The LOCAL seat's UI should refresh (its turn, or the table changed).
    private let onLocalTurn: () -> Void

    private let four: Bool

    public private(set) var game: Game

    /// game seat -> real seat for the current deal.
    private var dealMap: [Int] = [0, 1, 2]

    /// Real seat sitting out the current deal (-1 in 3-player games).
    public private(set) var sittingOut = -1

    public var sitOutName: String? {
        sittingOut >= 0 ? names[sittingOut] : nil
    }

    /// False while the host itself sits out (deals) in a 4-player match.
    public var hostActive: Bool {
        sittingOut != 0
    }

    public private(set) var matchEnded = false

    private var pendingResult: Calculation.GameResult?
    private var scoreWritten = false

    // ---- order-independent confirm stops -----------------------------------

    private let confirmPhases: Set<GamePhase> = [.PrikupOpened, .EndTurn, .EndPlay, .ScoreView]

    /// Real seats that confirmed the current stop.
    private var stopConfirmed = Set<Int>()
    private var stopId: String?

    /// Bumped whenever a new stop begins; used by the auto-confirm timer.
    public private(set) var stopKey: Int64 = 0

    private func humanSeats() -> [Int] {
        seats.indices.filter { seats[$0] != .bot }
    }

    /// The real seat whose own action produced the stop — no confirm needed:
    /// the last card of the trick, or the contractor at the opened prikup.
    private func stopMover() -> Int {
        switch game.phase {
        // after the closing card, playCard advanced playerInTurn one step back
        case .EndTurn:
            let g = (game.playerInTurn + 1) % 3
            return dealMap.indices.contains(g) ? dealMap[g] : -1
        case .PrikupOpened:
            return dealMap.indices.contains(game.contractor) ? dealMap[game.contractor] : -1
        default:
            return -1
        }
    }

    private func currentStopId() -> String? {
        let phase = game.phase
        if !confirmPhases.contains(phase) { return nil }
        let deal = ObjectIdentifier(game.deal).hashValue
        return "\(deal)-\(phase)-\(game.deal.totalTaken)"
    }

    /// True while the session waits for confirmations.
    public var atConfirmStop: Bool {
        stopId != nil && stopId == currentStopId()
    }

    public func hasConfirmed(_ seat: Int) -> Bool {
        atConfirmStop && stopConfirmed.contains(seat)
    }

    /// Names of the humans everyone is waiting for at the current stop.
    public func waitingNames() -> [String] {
        atConfirmStop ? humanSeats().filter { !stopConfirmed.contains($0) }.map { names[$0] } : []
    }

    /// A human confirmed the current stop (any order).
    public func confirmSeat(_ seat: Int) throws {
        if !confirmPhases.contains(game.phase) { return }
        if seat < 0 || seat >= seats.count || seats[seat] == .bot { return }
        if stopId != currentStopId() { return } // stale tap from a previous stop
        stopConfirmed.insert(seat)
        try pump()
    }

    /// Auto-confirm timer fired: everyone still pending is confirmed.
    public func confirmAll() throws {
        if !confirmPhases.contains(game.phase) { return }
        stopConfirmed.formUnion(humanSeats())
        try pump()
    }

    /// Run the engine's whole confirm cycle for the finished stop.
    private func applyStop() throws {
        switch game.phase {
        case .PrikupOpened:
            game.prikupClose()
            try game.next()
        case .EndTurn:
            while game.phase == .EndTurn {
                game.turnClose()
                try game.next()
            }
        case .EndPlay:
            while game.phase == .EndPlay {
                game.endConfirm()
                try game.next()
            }
        case .ScoreView:
            while game.phase == .ScoreView {
                game.scoreClose()
                try game.next()
            }
        default:
            break
        }
        stopId = nil
        stopConfirmed.removeAll()
    }

    // ------------------------------------------------------------------------

    // Animations produced by other seats' moves, replayed by the host UI.
    // Guests still get plain state snapshots.
    private var pendingAnims: [Game.Animation] = []

    /// Take (and clear) the queued animations. Call under the session lock.
    public func drainAnims() -> [Game.Animation] {
        let res = pendingAnims
        pendingAnims.removeAll()
        return res
    }

    public init(
        seats: [SeatKind],
        names: [String],
        matchCalc: Calculation,
        sendToSeat: @escaping (Int, GameMsg.State) -> Void,
        onLocalTurn: @escaping () -> Void
    ) {
        self.seats = seats
        self.names = names
        self.matchCalc = matchCalc
        self.sendToSeat = sendToSeat
        self.onLocalTurn = onLocalTurn
        self.four = seats.count == 4
        self.game = Game.create()
        if !four {
            game.calc = matchCalc
            game.externalDriver = true
        }
    }

    private func realOf(_ gameSeat: Int) -> Int {
        dealMap[gameSeat]
    }

    private func gameSeatOf(_ real: Int) -> Int {
        dealMap.firstIndex(of: real) ?? -1
    }

    public func start() throws {
        if four {
            try newDeal4()
        } else {
            try game.next()
        }
        try pump()
    }

    /// Deal the next 4-player round: matchCalc.dealer sits out.
    private func newDeal4() throws {
        let d = matchCalc.dealer
        sittingOut = d
        // the three actives in real seating order, starting left of the dealer
        let around = [(d + 1) % 4, (d + 2) % 4, (d + 3) % 4]
        let h = max(around.firstIndex(of: 0) ?? 0, 0)
        let a = Array(around.dropFirst(h)) + Array(around.prefix(h)) // host (real 0) first when active
        // the engine's turn order goes 0 -> 2 -> 1, so seat the circle to match
        dealMap = [a[0], a[2], a[1]]

        let c3 = Calculation(playersCount: 3, limit: matchCalc.limit)
        c3.rules = matchCalc.rules.clone()
        c3.created = matchCalc.created
        // raspasy progression only looks at game types/success, not indices
        c3.gameLog = matchCalc.gameLog
        for g in 0...2 {
            let r = dealMap[g]
            c3.scores[g].name = names[r]
            c3.scores[g].pulya = matchCalc.scores[r].pulya
            c3.scores[g].gora = matchCalc.scores[r].gora
            for g2 in 0...2 where g2 != g {
                c3.scores[g].visty[g2] = matchCalc.scores[r].visty[dealMap[g2]] ?? 0
            }
        }
        // the first bid belongs to the player left of the sitting dealer;
        // the engine gives it to (calc.dealer - 1 + 3) % 3
        c3.dealer = (gameSeatOf(around[0]) + 1) % 3

        let g = Game.create()
        g.calc = c3
        g.externalDriver = true
        g.singleDealMode = true
        game = g
        pendingResult = nil
        scoreWritten = false
        stopId = nil
        stopConfirmed.removeAll()
        try game.next()
    }

    /// Write the finished deal into the authoritative 4-player pulka.
    private func writeDealToMatch() {
        guard let r = pendingResult else { return }
        let m = Calculation.GameResult()
        m.gameType = r.gameType
        m.contract = r.contract
        m.multiplier = r.multiplier
        m.dealer = sittingOut
        m.contractor = (0..<dealMap.count).contains(r.contractor) ? dealMap[r.contractor] : 0
        for (k, v) in r.taken.entries {
            m.taken[dealMap[k]] = v
        }
        m.visters = r.visters.map { dealMap[$0] }
        // engine convention: the prikup card never wins a trick, so the
        // sitting dealer takes 0 on raspasy (and scores the non-taking pulya)
        if m.gameType == .Raspasy {
            m.taken[sittingOut] = 0
        }
        matchCalc.writeGame(m)
        scoreWritten = true
    }

    /// Advance until a human must act, playing bots inline.
    public func pump() throws {
        while true {
            pendingAnims.append(contentsOf: game.animations) // kept for the host UI to replay
            game.animations.removeAll()
            if four && game.phase == .EndPlay && pendingResult == nil {
                pendingResult = game.getGameResult() // before writeGame skews the multiplier
            }
            if four && game.phase == .ScoreView && !scoreWritten {
                writeDealToMatch()
            }
            if game.phase == .Ended {
                if !four { break } // 3p: the match itself is over
                if matchCalc.isFinished {
                    matchEnded = true
                    break
                }
                try newDeal4()
                continue
            }
            if confirmPhases.contains(game.phase) {
                let id = currentStopId()
                if stopId != id {
                    stopId = id
                    stopConfirmed.removeAll()
                    // whoever made the move that produced this stop saw it happen
                    let mover = stopMover()
                    if mover >= 0 {
                        stopConfirmed.insert(mover)
                    }
                    stopKey += 1
                }
                if humanSeats().allSatisfy({ stopConfirmed.contains($0) }) {
                    try applyStop()
                    continue
                }
                broadcast()
                onLocalTurn()
                return
            }
            switch seats[realOf(game.turnController())] {
            case .bot:
                do {
                    try AI.makeMove(game)
                } catch {
                    // Same rare positions the original swallowed: if the AI
                    // gives up while playing, make any legal move instead.
                    if game.phase == .Playing, let move = game.getAllowedMoves().first {
                        game.playCard(move)
                        try game.next()
                    } else {
                        throw error
                    }
                }
            case .local:
                broadcast()
                onLocalTurn()
                return
            case .remote:
                broadcast()
                onLocalTurn() // host UI keeps up while others act / it spectates
                return
            }
        }
        broadcast()
        onLocalTurn()
    }

    /// Send every REMOTE seat its personal view of the current state.
    private func broadcast(badMoveFor: Int = -1) {
        let ended = four ? matchEnded : game.phase == .Ended
        let atStop = atConfirmStop
        let waiting = waitingNames()
        let withScores = game.phase == .ScoreView || game.phase == .Ended
        for seat in seats.indices {
            if seats[seat] != .remote {
                continue
            }
            let confirmed = stopConfirmed.contains(seat) && atStop
            // a confirmed viewer already dismissed the score sheet; final
            // standings at game end always show
            let scoresFor = (withScores && !(confirmed && !ended))
                ? RemoteViews.buildScoresFrom(matchCalc, seat) : nil
            let g = gameSeatOf(seat)
            let yourTurn = !ended && (atStop
                ? !confirmed
                : g >= 0 && game.phase != .Ended && game.turnController() == g)
            let ask: Ask?
            if !yourTurn {
                ask = nil
            } else if atStop {
                ask = Ask("confirm")
            } else {
                ask = RemoteViews.buildAsk(game)
            }
            if g >= 0 {
                var fieldFor = RemoteViews.buildFieldFor(game, g)
                if confirmed && game.phase == .EndTurn {
                    fieldFor = fieldFor.filter { !$0.isInPlay }
                }
                sendToSeat(
                    seat,
                    GameMsg.State(
                        field: fieldFor,
                        info: RemoteViews.buildTableInfoFor(
                            game, g, sitOutName: sitOutName,
                            waitingFor: waiting, youConfirmed: confirmed
                        ),
                        yourTurn: yourTurn,
                        ask: ask,
                        badMove: seat == badMoveFor,
                        ended: ended,
                        scores: scoresFor
                    )
                )
            } else {
                // the sitting dealer spectates; they confirm the same stops
                sendToSeat(
                    seat,
                    GameMsg.State(
                        field: RemoteViews.buildFieldFor(game, 0, spectator: true),
                        info: RemoteViews.buildTableInfoFor(
                            game, 0, watching: true, sitOutName: sitOutName,
                            waitingFor: waiting, youConfirmed: confirmed
                        ),
                        yourTurn: yourTurn,
                        ask: ask,
                        badMove: false,
                        ended: ended,
                        scores: scoresFor
                    )
                )
            }
        }
    }

    /// Host ends the match early (after saving the pulka): everyone gets a
    /// final ended state with the standings.
    public func abortMatch() {
        matchEnded = true
        game.phase = .Ended
        broadcast()
    }

    /// Resend every guest's snapshot, e.g. after one of them reconnected.
    public func rebroadcast() {
        broadcast()
    }

    /// Apply a remote player's answer. Ignores messages from the wrong seat.
    public func onRemoteAct(_ seat: Int, _ act: GameMsg.Act) throws {
        guard seat >= 0, seat < seats.count, seats[seat] == .remote else { return }
        if matchEnded { return }
        if act.confirm == true && confirmPhases.contains(game.phase) {
            try confirmSeat(seat)
            return
        }
        if four && seat == sittingOut { return } // the spectator has no other input
        let g = gameSeatOf(seat)
        if g < 0 || game.phase == .Ended || game.turnController() != g { return }

        var ok = true
        switch game.phase {
        case .Negotiations:
            guard let bid = act.bid else { return }
            game.makeBid(bid)
        case .GameChoose:
            guard let bid = act.contract else { return }
            game.setContract(bid)
        case .VistNegotiations:
            guard let vist = act.vist else { return }
            game.setVist(vist)
        case .OpeningChoose:
            guard let opening = act.opening else { return }
            game.setOpeningChoice(opening)
        case .Discarding:
            guard let discard = act.discard else { return }
            let hand = game.deal.hands[g].cards
            let distinct = discard.count == 2 &&
                !(discard[0].value == discard[1].value && discard[0].coatColor == discard[1].coatColor)
            let present = distinct && discard.allSatisfy { d in
                hand.contains { $0.value == d.value && $0.coatColor == d.coatColor }
            }
            if present {
                game.discardCard(discard[0])
                game.discardCard(discard[1])
            }
            if game.deal.hands[g].cards.count != 10 {
                ok = false
            }
        case .Playing:
            guard let card = act.play else { return }
            if !game.playCard(card) {
                ok = false
            }
        default:
            return
        }

        if !ok {
            broadcast(badMoveFor: seat)
            return
        }
        try game.next()
        try pump()
    }

    /// The LOCAL seat acted through the normal UI path; continue the loop.
    public func onLocalActed() throws {
        try game.next()
        try pump()
    }
}
