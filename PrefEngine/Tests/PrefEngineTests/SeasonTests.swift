import XCTest
@testable import PrefEngine

/// The season contract. The reference numbers below are Android's SeasonTest
/// vectors, computed there with an independent implementation (Node.js
/// BigInt); this port must reproduce them exactly.
final class SeasonTests: XCTestCase {

    private let seed = "00112233445566778899aabbccddeeff"

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pref-season-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        PrefStorage.initialize(filesDir: dir)
    }

    private func ids(_ d: Deal) -> [[Int]] {
        d.hands.map { h in h.cards.map { $0.id } }
    }

    func testGeneratorMatchesTheReferenceVectors() {
        // Kotlin holds the state as a signed Long; compare the same bit pattern
        XCTAssertEqual(
            6927180097158232044,
            Int64(bitPattern: SeasonRandom.forPurpose(seed, "deal", 0).state)
        )

        let r = SeasonRandom.forPurpose(seed, "deal", 0)
        XCTAssertEqual([5, 4, 11, 27, 0, 25], (0..<6).map { _ in r.nextInt(32) })

        let d = SeasonRandom.forPurpose(seed, "bots", 7)
        XCTAssertEqual(0.32107593295955716, d.nextDouble())
        XCTAssertEqual(0.1639204827480535, d.nextDouble())
    }

    func testDealsMatchTheReferenceAndAreRepeatable() {
        let deal = Deal()
        deal.shuffle(SeasonRandom.forPurpose(seed, "deal", 3))
        XCTAssertEqual(
            [
                [311, 212, 12, 210, 313, 107, 108, 113, 209, 13],
                [110, 11, 312, 309, 310, 114, 214, 14, 8, 211],
                [10, 7, 314, 9, 112, 308, 207, 213, 307, 111],
            ],
            ids(deal)
        )
        XCTAssertEqual([208, 109], deal.prikup.cards.map { $0.id })

        // the same deal number is the same deal; another number is another deal
        let again = Deal()
        again.shuffle(SeasonRandom.forPurpose(seed, "deal", 3))
        XCTAssertEqual(ids(deal), ids(again))
        let other = Deal()
        other.shuffle(SeasonRandom.forPurpose(seed, "deal", 4))
        XCTAssertNotEqual(ids(deal), ids(other))
        // another season seed gives other deals
        let elsewhere = Deal()
        elsewhere.shuffle(SeasonRandom.forPurpose("ffee\(seed)", "deal", 3))
        XCTAssertNotEqual(ids(deal), ids(elsewhere))
    }

    func testConfigIsDerivedFromTheSeed() {
        let c = SeasonConfig.derive(seed)
        XCTAssertEqual(40, c.limit)
        XCTAssertEqual(.Rostov, c.rules.gameType)
        // Rostov applies its presets and forces "no progression"
        XCTAssertEqual(.NoProgression1, c.rules.raspasyProgression)
        XCTAssertEqual(.Each, c.rules.ending)
        XCTAssertEqual(.Max10, c.rules.consolationBonus)
        XCTAssertEqual(.Hard678, c.rules.raspasyExit)
        XCTAssertEqual(true, c.rules.miserRaspExit)
        XCTAssertEqual(.FullResponsibility, c.rules.vist)
        XCTAssertEqual(.Gentlemen, c.rules.consolation)
        XCTAssertEqual(false, c.rules.prikupConsolation)
        XCTAssertEqual(0, c.firstDealer)
    }

    func testSeasonsVaryAcrossTheWholeMenu() {
        let configs = (0..<400).map { SeasonConfig.derive("season-\($0)") }
        XCTAssertEqual(Set([10, 20, 40, 60]), Set(configs.map { $0.limit }))
        XCTAssertEqual(Set([RulesGameType.Sochy, .Leningrad, .Rostov]), Set(configs.map { $0.rules.gameType }))
        XCTAssertEqual(
            Set([RaspasyProgression.NoProgression1, .Arifm1233, .Geom1244]),
            Set(configs.map { $0.rules.raspasyProgression })
        )
        XCTAssertEqual(Set([0, 1, 2]), Set(configs.map { $0.firstDealer }))
    }

    private func runAllBotMatch() throws -> (Int, [String], Int) {
        let calc = Calculation(playersCount: 3, limit: 10)
        for i in 0...2 {
            calc.scores[i].name = "B\(i)"
        }
        calc.dealer = 1
        let session = HostGameSession(
            seats: [SeatKind](repeating: .bot, count: 3),
            names: ["B0", "B1", "B2"],
            matchCalc: calc,
            sendToSeat: { _, _ in },
            onLocalTurn: {}
        )
        session.game.seasonSeed = seed
        session.game.seasonDealIndex = 0
        try session.start()
        let sheet = (0...2).map { i -> String in
            let s = calc.scores[i]
            let visty = s.visty.entries.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
            return "\(s.pulya)/\(s.gora)/\(visty)"
        }
        return (calc.gameLog.count, sheet, session.game.seasonDealIndex)
    }

    func testASeasonMatchPlaysOutIdenticallyEveryTime() throws {
        // same deals AND seeded bots: two complete bot matches must agree on
        // every pool, whist and mountain entry
        let first = try runAllBotMatch()
        let second = try runAllBotMatch()
        XCTAssertGreaterThan(first.0, 5, "the match must have played deals")
        XCTAssertEqual(first.0, second.0)
        XCTAssertEqual(first.1, second.1)
        XCTAssertEqual(first.2, second.2)
    }

    func testASavedSeasonGameKeepsItsPlaceInTheSequence() throws {
        let state = SeasonState()
        state.seed = seed
        state.seasonId = "2026-11"
        let game = Seasons.newPoolGame(state, playerName: "Me", ai1Name: "West", ai2Name: "East")
        try game.newDeal()
        try game.newDeal()
        let json = PrefStorage.encodeToString(game)
        let back = try PrefStorage.decodeFromString(Game.self, json)
        XCTAssertEqual(seed, back.seasonSeed)
        XCTAssertEqual(2, back.seasonDealIndex)
        XCTAssertEqual(game.botRng!.state, back.botRng!.state)
        XCTAssertEqual(ids(game.deal), ids(back.deal))
    }

    func testASeasonGameHasItsOwnSaveSlot() throws {
        let state = SeasonState()
        state.seed = seed
        state.seasonId = "2026-11"
        let season = Seasons.newPoolGame(state, playerName: "Me", ai1Name: "West", ai2Name: "East")
        try season.newDeal()
        let normal = Game.create(ai1Name: "West", ai2Name: "East")
        normal.saveLast()
        season.saveLast()
        // neither overwrote the other, and each loads only as its own kind
        XCTAssertNil(Game.loadLast()?.seasonSeed, "the normal slot still holds the normal game")
        XCTAssertNotNil(Game.loadLast())
        XCTAssertEqual(seed, Game.loadSeason()?.seasonSeed)
        // a season file can never come back as the normal game
        PrefStorage.writeText("lastgame.json", PrefStorage.encodeToString(season))
        XCTAssertNil(Game.loadLast())
    }

    func testAClosedPoolCountsOnceAndTheNextPoolContinuesTheSequence() throws {
        let state = SeasonState()
        state.seed = seed
        state.seasonId = "2026-11"
        let game = Seasons.newPoolGame(state, playerName: "Me", ai1Name: "West", ai2Name: "East")
        for _ in 0..<7 {
            try game.newDeal() // the pool took deals 0..6
        }
        game.calc.dealer = 2
        Seasons.poolClosed(state, game, settlement: 12.5)
        Seasons.poolClosed(state, game, settlement: 12.5) // a second tap on Close changes nothing
        XCTAssertEqual(125, state.total10)
        XCTAssertEqual(1, state.poolsClosed)
        XCTAssertEqual(7, state.nextDealIndex)
        XCTAssertEqual(2, state.nextDealer)

        let next = Seasons.newPoolGame(state, playerName: "Me", ai1Name: "West", ai2Name: "East")
        XCTAssertEqual(7, next.seasonDealIndex)
        XCTAssertEqual(2, next.calc.dealer)
        try next.newDeal()
        // deal number 7 is the same cards for everyone
        let reference = Deal()
        reference.shuffle(SeasonRandom.forPurpose(seed, "deal", 7))
        XCTAssertEqual(ids(reference), ids(next.deal))

        Seasons.poolClosed(state, next, settlement: -4.0)
        XCTAssertEqual(125 - 40, state.total10)
        XCTAssertEqual(2, state.poolsClosed)
    }

    func testEveryClosedPoolIsPostedEvenWhenTheTotalIsNegative() throws {
        let state = SeasonState()
        state.seed = seed
        state.seasonId = "2026-11"
        XCTAssertEqual("total:2026-11", Seasons.boardName(state))
        XCTAssertFalse(Seasons.needsSubmit(state), "nothing to post before the first pool closes")

        let game = Seasons.newPoolGame(state, playerName: "Me", ai1Name: "West", ai2Name: "East")
        for _ in 0..<5 {
            try game.newDeal()
        }
        Seasons.poolClosed(state, game, settlement: -30.0)
        XCTAssertLessThan(state.total10, 0)
        XCTAssertTrue(Seasons.needsSubmit(state), "a negative total must still be posted")

        state.submittedPools = state.poolsClosed // the server accepted it
        XCTAssertFalse(Seasons.needsSubmit(state))

        for _ in 0..<4 {
            try game.newDeal()
        }
        Seasons.poolClosed(state, game, settlement: 30.0) // back to exactly zero
        XCTAssertEqual(0, state.total10)
        XCTAssertTrue(Seasons.needsSubmit(state), "a total of zero is posted too")
    }

    func testNegativeHalfWhistSettlementsRoundLikeAndroid() {
        // Kotlin roundToLong sends -42.5 to -42 (ties toward +infinity)
        let state = SeasonState()
        state.seed = seed
        let game = Seasons.newPoolGame(state, playerName: "Me", ai1Name: "West", ai2Name: "East")
        game.seasonDealIndex = 3
        Seasons.poolClosed(state, game, settlement: -4.25)
        XCTAssertEqual(-42, state.total10)
    }

    func testDaysLeftRoundsUp() {
        let s = SeasonState()
        s.endsAt = 1_000_000
        XCTAssertEqual(1, Seasons.daysLeft(s, now: 1_000_000 - 3600))
        XCTAssertEqual(2, Seasons.daysLeft(s, now: 1_000_000 - 86400 - 1))
        XCTAssertEqual(0, Seasons.daysLeft(s, now: 1_000_000))
        XCTAssertTrue(Seasons.isOver(s, now: 1_000_001))
    }

    /// Cross-check against the independent Node oracle for ANY seed (used for the
    /// live season): PREF_SEASON_SEED=<hex> PREF_SEASON_DUMP=<file> swift test --filter testDumpSeason
    func testDumpSeasonForSeed() throws {
        let env = ProcessInfo.processInfo.environment
        guard let seed = env["PREF_SEASON_SEED"], let path = env["PREF_SEASON_DUMP"] else {
            throw XCTSkip("cross-check dump; set PREF_SEASON_SEED and PREF_SEASON_DUMP")
        }
        let c = SeasonConfig.derive(seed)
        func dealJSON(_ i: Int) -> [String: Any] {
            let d = Deal()
            d.shuffle(SeasonRandom.forPurpose(seed, "deal", i))
            return ["index": i, "hands": ids(d), "prikup": d.prikup.cards.map { $0.id }]
        }
        let bots = SeasonRandom.forPurpose(seed, "bots", 7)
        let out: [String: Any] = [
            "config": [
                "limit": c.limit, "type": c.rules.gameType.rawValue,
                "progression": c.rules.raspasyProgression.rawValue, "exit": c.rules.raspasyExit.rawValue,
                "miserExit": c.rules.miserRaspExit, "vist": c.rules.vist.rawValue,
                "consolation": c.rules.consolation.rawValue, "talon": c.rules.prikupConsolation,
                "firstDealer": c.firstDealer,
            ],
            "deals": [0, 1, 2, 7].map(dealJSON),
            "botDoubles": [bots.nextDouble(), bots.nextDouble()],
        ]
        let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Plays whole seasons with every seat on the bots and returns one line per
    /// deal, in the exact format of the Kotlin driver that runs Android's real
    /// engine (tools/parity). The two outputs must be identical, line for line.
    private func parityTranscript(seed: String, pools: Int) throws -> String {
        let cfg = SeasonConfig.derive(seed)
        let state = SeasonState()
        state.seed = seed
        state.seasonId = "parity"
        state.nextDealer = cfg.firstDealer
        var out = "CONFIG limit=\(cfg.limit) type=\(cfg.rules.gameType) prog=\(cfg.rules.raspasyProgression) exit=\(cfg.rules.raspasyExit) dealer=\(cfg.firstDealer)\n"
        for pool in 0..<pools {
            let game = Seasons.newPoolGame(state, playerName: "Me", ai1Name: "West", ai2Name: "East")
            var logged = 0
            try game.next()
            var steps = 0
            var fallbacks = 0
            while game.phase != .Ended && steps < 200_000 {
                steps += 1
                do {
                    try AI.makeMove(game)
                } catch {
                    // identical to HostGameSession's fallback for rare positions
                    if game.phase == .Playing, let move = game.getAllowedMoves().first {
                        fallbacks += 1
                        game.playCard(move)
                        try game.next()
                    } else {
                        throw error
                    }
                }
                while logged < game.calc.gameLog.count {
                    let r = game.calc.gameLog[logged]
                    let t = r.taken.entries.sorted { $0.key < $1.key }.map { String($0.value) }.joined(separator: ",")
                    let v = r.visters.sorted().map(String.init).joined(separator: ",")
                    let rng = game.botRng.map { String(Int64(bitPattern: $0.state)) } ?? "null"
                    out += "P\(pool) D\(logged) \(r.gameType) c=\(r.contractor) k=\(r.contract) t=\(t) v=\(v) d=\(r.dealer) m=\(r.multiplier) rng=\(rng) idx=\(game.seasonDealIndex)\n"
                    logged += 1
                }
            }
            game.calc.calc() // the results screen computes the final settlement
            let sc = game.calc.scores
            let sheet = (0...2).map { i -> String in
                let visty = sc[i].visty.entries.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
                return "[\(sc[i].pulya)/\(sc[i].gora)/\(visty)]"
            }.joined(separator: " ")
            let settle = (0...2).map { String(roundToLongHalfUp(sc[$0].score * 10)) }.joined(separator: ",")
            out += "POOL \(pool) deals=\(game.calc.gameLog.count) steps=\(steps) fallbacks=\(fallbacks) sheet=\(sheet) settlement10=\(settle)\n"
            Seasons.poolClosed(state, game, settlement: sc[0].score)
        }
        out += "TOTAL total10=\(state.total10) pools=\(state.poolsClosed) next=\(state.nextDealIndex) dealer=\(state.nextDealer)\n"
        return out
    }

    /// The bots play seasons exactly like Android's: two short seasons (three
    /// pools each) replayed against transcripts produced by Android's own engine.
    /// A mismatch means the AI, the engine or the RNG draw order drifted from
    /// Android, which would split season players' results.
    func testBotsPlaySeasonsLikeAndroid() throws {
        for (seed, golden) in [
            ("parity-seed-02", SeasonParityFixtures.transcript_parity_seed_02),
            ("parity-seed-05", SeasonParityFixtures.transcript_parity_seed_05),
        ] {
            let mine = try parityTranscript(seed: seed, pools: 3)
            let want = golden.split(separator: "\n").map(String.init) // literals drop the final newline
            let got = mine.split(separator: "\n").map(String.init)
            XCTAssertEqual(want.count, got.count, "\(seed): transcript length")
            for (i, (a, b)) in zip(want, got).enumerated() where a != b {
                XCTFail("\(seed) line \(i + 1) differs from Android's engine:\n  android: \(a)\n  swift:   \(b)")
                break
            }
        }
    }

    /// Any seed, any number of pools; writes the transcript for diffing with the
    /// Kotlin driver (tools/parity/run_parity.sh does this for you).
    ///   PREF_PARITY_SEED=<hex> PREF_PARITY_POOLS=3 PREF_PARITY_DUMP=<file> swift test --filter testDumpSeasonBotRun
    func testDumpSeasonBotRun() throws {
        let env = ProcessInfo.processInfo.environment
        guard let seed = env["PREF_PARITY_SEED"], let path = env["PREF_PARITY_DUMP"] else {
            throw XCTSkip("bot-parity dump; set PREF_PARITY_SEED, PREF_PARITY_POOLS and PREF_PARITY_DUMP")
        }
        let pools = Int(env["PREF_PARITY_POOLS"] ?? "3") ?? 3
        try parityTranscript(seed: seed, pools: pools).write(toFile: path, atomically: true, encoding: .utf8)
    }
}
