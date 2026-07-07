import XCTest
@testable import PrefEngine

/// Engine smoke test: plays full games with all three seats driven by the AI.
/// The human seat is driven by the same AI.makeMove dispatcher the game uses
/// for computer players, which exercises bidding, discarding, all game types
/// (contract, miser, raspasy) and scoring end to end.
final class GameEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pref-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        PrefStorage.initialize(filesDir: dir)
    }

    func testPlaysFullGamesWithoutCrashing() throws {
        for round in 0..<3 {
            let game = Game.create()
            game.calc.limit = 4 // short game
            var steps = 0
            try game.next()
            while game.phase != .Ended && steps < 20000 {
                do {
                    try AI.makeMove(game)
                } catch {
                    // Paths where the original game waits for the human (e.g. the
                    // player catches a misère or leads open-whist hands): play like
                    // a human tapping the first allowed card.
                    if game.phase == .Playing {
                        let moves = game.getAllowedMoves()
                        game.playCard(moves.first!)
                        try game.next()
                    } else {
                        throw error
                    }
                }
                steps += 1
            }
            print("Round \(round): phase=\(game.phase) deals=\(game.calc.gameLog.count) steps=\(steps)")
            XCTAssertTrue(!game.calc.gameLog.isEmpty, "game must progress (deals played)")
            XCTAssertTrue(game.phase == .Ended, "game must finish in a bounded number of steps")
        }
    }

    func testPulkaReorderRemapsAllPlayerReferences() {
        let c = Calculation(playersCount: 3, limit: 10)
        c.scores[0].name = "Anna"
        c.scores[1].name = "Boris"
        c.scores[2].name = "Clara"
        c.scores[1].pulya = 5
        c.scores[1].gora = 12
        c.scores[1].visty[2] = 40
        c.dealer = 1

        // Boris hosts the resumed game; Clara joins; a bot takes Anna's column
        let order = Calculation.seatOrder(["boris ", "CLARA", "Bot"], c)
        XCTAssertEqual([1, 2, 0], order, "name match with order fallback")

        let r = c.reordered(order)
        XCTAssertTrue(r.scores[0].name == "Boris" && r.scores[0].pulya == 5 && r.scores[0].gora == 12)
        XCTAssertEqual(40, r.scores[0].visty[1], "visty keys remapped (Boris on Clara)")
        XCTAssertEqual(0, r.dealer, "dealer follows its player")
        XCTAssertTrue(r.limit == c.limit && r.created == c.created, "limit and created preserved")
    }

    func testSavesAndLoadsGame() throws {
        let game = Game.create()
        try game.next() // deals cards, runs negotiations until human input is needed
        game.saveLast()
        let loaded = Game.loadLast()
        XCTAssertTrue(loaded != nil)
        XCTAssertTrue(loaded!.calc.playersCount == 3)
        XCTAssertTrue(loaded!.deal.hands.reduce(0) { $0 + $1.cards.count } + loaded!.deal.prikup.cards.count == 32)
    }
}
