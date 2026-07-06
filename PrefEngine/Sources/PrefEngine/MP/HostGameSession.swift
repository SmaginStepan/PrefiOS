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
/// Single-threaded by design: the caller must serialize calls (the app runs
/// it on one queue; the unit test calls it directly).
public final class HostGameSession {

    public let game: Game
    private let seats: [SeatKind]
    /// Deliver a state message to a REMOTE seat (absolute seat number).
    private let sendToSeat: (Int, GameMsg.State) -> Void
    /// The LOCAL seat (host UI) should refresh / take its turn.
    private let onLocalTurn: () -> Void

    public init(
        game: Game,
        seats: [SeatKind],
        sendToSeat: @escaping (Int, GameMsg.State) -> Void,
        onLocalTurn: @escaping () -> Void
    ) {
        self.game = game
        self.seats = seats
        self.sendToSeat = sendToSeat
        self.onLocalTurn = onLocalTurn
        game.externalDriver = true
    }

    public func start() throws {
        try game.next()
        try pump()
    }

    /// Advance until a human (local or remote) must act, playing bots inline.
    public func pump() throws {
        while game.phase != .Ended {
            game.animations.removeAll() // multiplayer sends state snapshots instead
            switch seats[game.playerInTurn] {
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
                return
            }
        }
        broadcast()
    }

    /// Send every REMOTE seat its personal view of the current state.
    private func broadcast(badMoveFor: Int = -1) {
        let ended = game.phase == .Ended
        let withScores = ended || game.phase == .ScoreView
        for seat in seats.indices {
            if seats[seat] != .remote {
                continue
            }
            let yourTurn = !ended && game.playerInTurn == seat
            sendToSeat(
                seat,
                GameMsg.State(
                    field: RemoteViews.buildFieldFor(game, seat),
                    info: RemoteViews.buildTableInfoFor(game, seat),
                    yourTurn: yourTurn,
                    ask: yourTurn ? RemoteViews.buildAsk(game) : nil,
                    badMove: seat == badMoveFor,
                    ended: ended,
                    scores: withScores ? RemoteViews.buildScoresFor(game, seat) : nil
                )
            )
        }
    }

    /// Apply a remote player's answer. Ignores messages from the wrong seat.
    public func onRemoteAct(_ seat: Int, _ act: GameMsg.Act) throws {
        guard seat >= 0, seat < seats.count, seats[seat] == .remote else { return }
        if game.phase == .Ended || game.playerInTurn != seat {
            return
        }

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
            let hand = game.deal.hands[seat].cards
            let distinct = discard.count == 2 &&
                !(discard[0].value == discard[1].value && discard[0].coatColor == discard[1].coatColor)
            let present = distinct && discard.allSatisfy { d in
                hand.contains { $0.value == d.value && $0.coatColor == d.coatColor }
            }
            if present {
                game.discardCard(discard[0])
                game.discardCard(discard[1])
            }
            if game.deal.hands[seat].cards.count != 10 {
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
