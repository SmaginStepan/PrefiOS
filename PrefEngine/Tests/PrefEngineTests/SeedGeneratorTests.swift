import XCTest
@testable import PrefEngine

/// Not a test: generates seeded save files for App Store screenshots.
/// Run with PREF_SEED_DIR=/path swift test --filter SeedGeneratorTests —
/// writes <dir>/<lang>/{settings,lastgame,lastcalc}.json per language.
final class SeedGeneratorTests: XCTestCase {

    func testGenerateScreenshotSeeds() throws {
        guard let root = ProcessInfo.processInfo.environment["PREF_SEED_DIR"] else {
            throw XCTSkip("seed generator; run with PREF_SEED_DIR=/path")
        }
        let langs: [(String, [String])] = [
            ("en", ["Player", "West", "East"]),
            ("ru", ["Игрок", "Запад", "Восток"]),
            ("es", ["Jugador", "Oeste", "Este"]),
        ]
        for (lang, names) in langs {
            let dir = URL(fileURLWithPath: root).appendingPathComponent(lang)
            try? FileManager.default.removeItem(at: dir)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            PrefStorage.initialize(filesDir: dir)

            // settings.json with the localized player name
            let settings = AppSettings()
            settings.playerName = names[0]

            // lastgame.json: a photogenic mid-play state — normal game, the
            // human's turn, two cards already on the table, a few tricks done
            var saved = false
            for _ in 0..<300 where !saved {
                let game = Game.create(ai1Name: names[1], ai2Name: names[2])
                game.calc.scores[0].name = names[0]
                try game.next()
                var steps = 0
                while game.phase != .Ended && steps < 3000 {
                    steps += 1
                    if game.phase == .Playing && game.currentGameType == .Normal
                        && game.playerInTurn == 0 && game.turnController() == 0 && !game.isAI()
                        && (2...6).contains(game.deal.totalTaken)
                        && game.deal.inPlay.count == 2 {
                        game.saveLast()
                        saved = true
                        break
                    }
                    do {
                        try AI.makeMove(game)
                    } catch {
                        if game.phase == .Playing, let move = game.getAllowedMoves().first {
                            game.playCard(move)
                            try game.next()
                        } else {
                            break
                        }
                    }
                }
            }
            XCTAssertTrue(saved, "no seed state found for \(lang)")

            // lastcalc.json: a pulka with a bit of history in every cell type
            let calc = Calculation(playersCount: 3, limit: 10)
            for (i, name) in names.enumerated() {
                calc.scores[i].name = name
            }
            calc.dealer = 1
            func result(_ build: (Calculation.GameResult) -> Void) -> Calculation.GameResult {
                let r = Calculation.GameResult()
                build(r)
                return r
            }
            calc.writeGame(result { r in
                r.gameType = .Raspasy
                r.dealer = 0
                r.taken[0] = 2; r.taken[1] = 4; r.taken[2] = 4
            })
            calc.writeGame(result { r in
                r.gameType = .Normal
                r.contract = 6
                r.contractor = 1
                r.dealer = 1
                r.visters = [0, 2]
                r.taken[1] = 6; r.taken[0] = 2; r.taken[2] = 2
            })
            calc.writeGame(result { r in
                r.gameType = .Normal
                r.contract = 7
                r.contractor = 0
                r.dealer = 2
                r.visters = [2]
                r.taken[0] = 7; r.taken[2] = 2; r.taken[1] = 1
            })
            calc.writeGame(result { r in
                r.gameType = .Miser
                r.contractor = 2
                r.dealer = 0
                r.taken[2] = 0
            })
            calc.saveLast()
            print("seeded \(lang): \(dir.path)")
        }
    }
}
