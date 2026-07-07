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
    private var dealerConfirmed = true

    // A human sitting dealer watches the deal at its own pace: the game holds
    // at the prikup, after every trick and at the deal result until they tap.
    private var spectatorSawTrick = -1 // deal.totalTaken value already confirmed
    private var spectatorSawPrikup = false
    private var spectatorSawEndPlay = false

    private var dealerIsHuman: Bool {
        four && sittingOut >= 0 && seats[sittingOut] != .bot
    }

    /// The sitting dealer must tap through the current mid-deal stop.
    private func spectatorHold() -> Bool {
        if !dealerIsHuman { return false }
        switch game.phase {
        case .PrikupOpened: return !spectatorSawPrikup
        case .EndTurn: return spectatorSawTrick != game.deal.totalTaken
        case .EndPlay: return !spectatorSawEndPlay
        default: return false
        }
    }

    // Animations produced by other seats' moves, replayed by the host UI.
    // Guests still get plain state snapshots.
    private var pendingAnims: [Game.Animation] = []

    /// Take (and clear) the queued animations. Call under the session lock.
    public func drainAnims() -> [Game.Animation] {
        let res = pendingAnims
        pendingAnims.removeAll()
        return res
    }

    // Seats (real) that already confirmed the trick being shown in EndTurn:
    // the engine keeps it in deal.inPlay until everyone confirmed, but a
    // player who tapped through shouldn't see it come back. Tied to the
    // trick number: a passive player can see several tricks go by without
    // the phase ever leaving EndTurn between their confirms.
    private var trickConfirmed = Set<Int>()
    private var trickConfirmedAt = -1

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

    /// True when the sitting dealer still has to confirm the deal's score.
    public var awaitingDealerConfirm: Bool {
        four && scoreWritten && !dealerConfirmed &&
            (game.phase == .ScoreView || game.phase == .Ended)
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
        dealerConfirmed = seats[d] == .bot
        spectatorSawTrick = -1
        spectatorSawPrikup = false
        spectatorSawEndPlay = false
        trickConfirmed.removeAll()
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

    /// Advance until a human (local or remote) must act, playing bots inline.
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
                if !dealerConfirmed { break } // hold until the sitting dealer taps through
                if matchCalc.isFinished {
                    matchEnded = true
                    break
                }
                try newDeal4()
                continue
            }
            if spectatorHold() {
                // wait for the sitting dealer's tap before the actives move on
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
        if game.phase != .EndTurn || game.deal.totalTaken != trickConfirmedAt {
            trickConfirmed.removeAll()
        }
        let ended = four ? matchEnded : game.phase == .Ended
        let withScores = game.phase == .ScoreView || game.phase == .Ended
        for seat in seats.indices {
            if seats[seat] != .remote {
                continue
            }
            let g = gameSeatOf(seat)
            if g >= 0 {
                let yourTurn = !ended && game.phase != .Ended && game.turnController() == g
                var fieldFor = RemoteViews.buildFieldFor(game, g)
                if trickConfirmed.contains(seat) {
                    fieldFor = fieldFor.filter { !$0.isInPlay }
                }
                sendToSeat(
                    seat,
                    GameMsg.State(
                        field: fieldFor,
                        info: RemoteViews.buildTableInfoFor(game, g, sitOutName: sitOutName),
                        yourTurn: yourTurn,
                        ask: yourTurn ? RemoteViews.buildAsk(game) : nil,
                        badMove: seat == badMoveFor,
                        ended: ended,
                        scores: withScores ? RemoteViews.buildScoresFrom(matchCalc, seat) : nil
                    )
                )
            } else {
                // the sitting dealer spectates; they tap through the prikup,
                // every trick, the deal result and the score sheet
                let confirm = !ended && (awaitingDealerConfirm || spectatorHold())
                sendToSeat(
                    seat,
                    GameMsg.State(
                        field: RemoteViews.buildFieldFor(game, 0, spectator: true),
                        info: RemoteViews.buildTableInfoFor(game, 0, watching: true, sitOutName: sitOutName),
                        yourTurn: confirm,
                        ask: confirm ? Ask("confirm") : nil,
                        badMove: false,
                        ended: ended,
                        scores: withScores ? RemoteViews.buildScoresFrom(matchCalc, seat) : nil
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

    /// Anything the sitting dealer may currently tap through.
    public var spectatorAwaiting: Bool {
        awaitingDealerConfirm || spectatorHold()
    }

    /// The sitting dealer tapped: release whatever stop is pending.
    public func dealerConfirm() throws {
        if awaitingDealerConfirm {
            dealerConfirmed = true
            if game.phase == .Ended {
                try pump()
            }
            return
        }
        if !spectatorHold() { return }
        switch game.phase {
        case .PrikupOpened: spectatorSawPrikup = true
        case .EndTurn: spectatorSawTrick = game.deal.totalTaken
        case .EndPlay: spectatorSawEndPlay = true
        default: return
        }
        try pump()
    }

    /// Apply a remote player's answer. Ignores messages from the wrong seat.
    public func onRemoteAct(_ seat: Int, _ act: GameMsg.Act) throws {
        guard seat >= 0, seat < seats.count, seats[seat] == .remote else { return }
        if matchEnded { return }
        if four && seat == sittingOut {
            if act.confirm == true {
                try dealerConfirm()
            }
            return
        }
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
        case .PrikupOpened:
            guard act.confirm == true else { return }
            game.prikupClose()
        case .EndTurn:
            guard act.confirm == true else { return }
            trickConfirmed.insert(seat)
            trickConfirmedAt = game.deal.totalTaken
            game.turnClose()
        case .EndPlay:
            guard act.confirm == true else { return }
            game.endConfirm()
        case .ScoreView:
            guard act.confirm == true else { return }
            game.scoreClose()
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
