import XCTest
@testable import PrefEngine

/// Milestone test for hosted multiplayer: all three seats are simulated REMOTE
/// clients that act purely on the protocol messages they receive — exactly what
/// real guests will do. Verifies the pump loop, action application, JSON
/// round-tripping of every message, and that no snapshot ever leaks a hidden card.
final class HostGameSessionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pref-mp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        PrefStorage.initialize(filesDir: dir)
    }

    private final class RemotePlayer {
        var hasBidThisDeal = false
    }

    func testHostSeesOwnHandInHostedGame() throws {
        let game = Game.create()
        game.externalDriver = true
        try game.next() // deals; waits for seat input
        let field = TableLayout.computeField(game)
        let ownFaceUp = field.filter { $0.hand == 0 && !$0.isInPlay && !$0.isPrikup && $0.card != nil }.count
        let othersFaceDown = field.filter { (1...2).contains($0.hand) && !$0.isInPlay && !$0.isPrikup && $0.card == nil }.count
        XCTAssertEqual(10, ownFaceUp, "host sees all 10 own cards")
        XCTAssertEqual(20, othersFaceDown, "opponents stay face-down")
    }

    func testThreeRemotePlayersFinishGamesWithoutLeaks() throws {
        for round in 0..<3 {
            let game = Game.create()
            game.calc.limit = 4
            let seats: [SeatKind] = [.remote, .remote, .remote]
            let players = (0..<3).map { _ in RemotePlayer() }
            var pending: [(Int, GameMsg.State)] = []
            var leaks = 0
            var statesSent = 0

            let session = HostGameSession(
                game: game,
                seats: seats,
                sendToSeat: { seat, msg in
                    statesSent += 1
                    // wire round-trip: everything must survive JSON
                    do {
                        let wire = try WireJSON.encodeToString(GameMsg.state(msg))
                        let decodedMsg = try WireJSON.decodeFromString(GameMsg.self, wire)
                        guard case .state(let decoded) = decodedMsg else {
                            XCTFail("state did not survive the wire")
                            return
                        }
                        // redaction check: relative hands 1..2 must be face-down
                        // unless the absolute hand is opened by play
                        for pc in decoded.field {
                            if (1...2).contains(pc.hand) && !pc.isInPlay && !pc.isPrikup && pc.card != nil {
                                let absolute = (pc.hand + seat) % 3
                                if !game.deal.hands[absolute].isVisible {
                                    leaks += 1
                                }
                            }
                        }
                        pending.append((seat, decoded))
                    } catch {
                        XCTFail("wire round-trip failed: \(error)")
                    }
                },
                onLocalTurn: {}
            )
            try session.start()

            var steps = 0
            while game.phase != .Ended && steps < 200_000 {
                steps += 1
                guard !pending.isEmpty else { break }
                let (seat, st) = pending.removeFirst()
                if !st.yourTurn { continue }
                guard let ask = st.ask else { continue }
                if st.info.phase == .Negotiations && st.info.curentBids.isEmpty {
                    players.forEach { $0.hasBidThisDeal = false }
                }
                let me = players[seat]
                var act: GameMsg.Act?
                switch ask.kind {
                case "bid":
                    let bids = ask.bids ?? []
                    let real = bids.first { !$0.pas && !$0.miser }
                    if !me.hasBidThisDeal, let real = real {
                        me.hasBidThisDeal = true
                        act = GameMsg.Act(bid: real)
                    } else {
                        act = GameMsg.Act(bid: bids.first { $0.pas }!)
                    }
                case "contract":
                    act = GameMsg.Act(contract: ask.bids!.first!)
                case "vist":
                    act = GameMsg.Act(vist: true)
                case "opening":
                    act = GameMsg.Act(opening: true)
                case "discard":
                    let mine = st.field.filter {
                        $0.hand == 0 && $0.card != nil && !$0.isInPlay && !$0.isPrikup
                    }.map { $0.card! }
                    act = GameMsg.Act(discard: Array(mine.prefix(2)))
                case "play":
                    act = GameMsg.Act(play: ask.allowed!.first!)
                case "confirm":
                    act = GameMsg.Act(confirm: true)
                default:
                    act = nil
                }
                if let act = act {
                    // wire round-trip for the act too
                    let wire = try WireJSON.encodeToString(GameMsg.act(act))
                    guard case .act(let decodedAct) = try WireJSON.decodeFromString(GameMsg.self, wire) else {
                        XCTFail("act did not survive the wire")
                        continue
                    }
                    try session.onRemoteAct(seat, decodedAct)
                }
            }

            print("Round \(round): phase=\(game.phase) deals=\(game.calc.gameLog.count) states=\(statesSent) steps=\(steps)")
            XCTAssertEqual(0, leaks, "no hidden cards may leak")
            XCTAssertTrue(!game.calc.gameLog.isEmpty, "deals were played")
            XCTAssertEqual(GamePhase.Ended, game.phase, "game finished")
        }
    }
}
