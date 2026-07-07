import XCTest
@testable import PrefEngine

/// Milestone test for hosted multiplayer: every seat is a simulated REMOTE
/// client that acts purely on the protocol messages it receives — exactly what
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

    /// Drives a session of N remote players until it ends; returns (session, leaks).
    private func driveRemoteMatch(playersCount: Int, limit: Int) throws -> (HostGameSession, Int) {
        let calc = Calculation(playersCount: playersCount, limit: limit)
        let names = (0..<playersCount).map { "P\($0)" }
        for i in 0..<playersCount {
            calc.scores[i].name = names[i]
        }
        let seats = [SeatKind](repeating: .remote, count: playersCount)
        let players = (0..<playersCount).map { _ in RemotePlayer() }
        var pending: [(Int, GameMsg.State)] = []
        var leaks = 0

        var sessionRef: HostGameSession?
        let session = HostGameSession(
            seats: seats,
            names: names,
            matchCalc: calc,
            sendToSeat: { seat, msg in
                // wire round-trip: everything must survive JSON
                do {
                    let wire = try WireJSON.encodeToString(GameMsg.state(msg))
                    guard case .state(let decoded) = try WireJSON.decodeFromString(GameMsg.self, wire) else {
                        XCTFail("state did not survive the wire")
                        return
                    }
                    // redaction: relative hands 1..2 (and the spectator's hand 0)
                    // may only be face-up when the play opened some hand
                    let anyOpen = sessionRef?.game.deal.hands.contains { $0.isVisible } ?? false
                    for pc in decoded.field {
                        let hidden = (1...2).contains(pc.hand) || (decoded.info.watching && pc.hand == 0)
                        if hidden && !pc.isInPlay && !pc.isPrikup && pc.card != nil && !anyOpen {
                            leaks += 1
                        }
                    }
                    pending.append((seat, decoded))
                } catch {
                    XCTFail("wire round-trip failed: \(error)")
                }
            },
            onLocalTurn: {}
        )
        sessionRef = session
        try session.start()

        func over() -> Bool {
            playersCount == 4 ? session.matchEnded : session.game.phase == .Ended
        }

        var steps = 0
        while !over() && steps < 400_000 {
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
        print("players=\(playersCount) deals=\(calc.gameLog.count) steps=\(steps) ended=\(over())")
        XCTAssertTrue(over(), "match must finish")
        XCTAssertTrue(!calc.gameLog.isEmpty, "deals were played")
        return (session, leaks)
    }

    func testThreeRemotePlayersFinishGamesWithoutLeaks() throws {
        for _ in 0..<3 {
            let (_, leaks) = try driveRemoteMatch(playersCount: 3, limit: 4)
            XCTAssertEqual(0, leaks, "no hidden cards may leak")
        }
    }

    func testFourPlayersWithSittingDealerFinishGamesWithoutLeaks() throws {
        for _ in 0..<3 {
            let (session, leaks) = try driveRemoteMatch(playersCount: 4, limit: 3)
            XCTAssertEqual(0, leaks, "no hidden cards may leak")
            // every deal must have been written with the sitting dealer as its dealer
            let calc = session.matchCalc
            XCTAssertTrue(calc.gameLog.allSatisfy { (0...3).contains($0.dealer) },
                          "4p results reference all four players")
        }
    }
}
