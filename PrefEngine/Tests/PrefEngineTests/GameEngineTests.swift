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
