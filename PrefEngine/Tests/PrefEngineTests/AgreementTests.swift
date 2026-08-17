import XCTest
@testable import PrefEngine

/// Agreement («расписать») engine flow and the conservative bot rule.
/// Port of the Android AgreementTest.
final class AgreementTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pref-agree-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        PrefStorage.initialize(filesDir: dir)
    }

    /// Drives a fresh externally-driven game into the play of 6♦ with one whister.
    private func gameAtPlay() throws -> Game {
        let game = Game.create()
        game.externalDriver = true
        return try driveToPlay(game)
    }

    /// trump 2 (diamonds) = one whister; trump 0 (spades) can trigger the
    /// Stalingrad rule and auto-whist both opponents.
    @discardableResult
    private func driveToPlay(_ game: Game, trump: Int = 2) throws -> Game {
        try game.next()
        let bid6 = Game.Bid()
        bid6.contract = 6
        bid6.trump = trump
        game.makeBid(bid6)
        try game.next()
        let pas1 = Game.Bid()
        pas1.pas = true
        game.makeBid(pas1)
        try game.next()
        let pas2 = Game.Bid()
        pas2.pas = true
        game.makeBid(pas2)
        try game.next()
        XCTAssertEqual(GamePhase.PrikupOpened, game.phase)
        while game.phase == .PrikupOpened {
            game.prikupClose()
            try game.next()
        }
        XCTAssertEqual(GamePhase.Discarding, game.phase)
        let hand = game.deal.hands[game.contractor].cards
        game.discardCard(hand[0])
        game.discardCard(hand[1])
        try game.next()
        XCTAssertEqual(GamePhase.GameChoose, game.phase)
        let contractBid = Game.Bid()
        contractBid.contract = 6
        contractBid.trump = trump
        game.setContract(contractBid)
        try game.next()
        if game.phase == .VistNegotiations {
            game.setVist(true)
            try game.next()
            if game.phase == .VistNegotiations {
                game.setVist(false)
                try game.next()
            }
        }
        if game.phase == .OpeningChoose {
            game.setOpeningChoice(false)
            try game.next()
        }
        XCTAssertEqual(GamePhase.Playing, game.phase)
        return game
    }

    func testAgreementScoresLikeAPlayedDeal() throws {
        let game = try gameAtPlay()
        let c = game.contractor
        let whister = game.isVister.entries.first { $0.value }!.key
        let passer = (0...2).first { $0 != c && $0 != whister }!
        // agreed: declarer makes exactly the contract
        game.applyAgreement([c: 6, whister: 4, passer: 0])
        XCTAssertEqual(GamePhase.EndPlay, game.phase)
        for _ in 0..<3 {
            game.endConfirm()
            try game.next()
        }
        XCTAssertEqual(GamePhase.ScoreView, game.phase)
        XCTAssertEqual(2, game.calc.scores[c].pulya, "pulya for the made 6-game")
        XCTAssertEqual(8, game.calc.scores[whister].visty[c] ?? 0, "whister writes 4 tricks x 2")
        XCTAssertEqual(0, game.calc.scores[passer].visty[c] ?? 0, "passer writes nothing")
    }

    func testSurrenderWritesMountainOnlyAndVoidsWhists() throws {
        let game = try gameAtPlay()
        let c = game.contractor
        let whister = game.isVister.entries.first { $0.value }!.key
        let passer = (0...2).first { $0 != c && $0 != whister }!
        // «без 3 (застрелиться)»: unilateral, whists voided
        game.applyAgreement([c: 3, whister: 7, passer: 0], noVists: true)
        for _ in 0..<3 {
            game.endConfirm()
            try game.next()
        }
        XCTAssertEqual(GamePhase.ScoreView, game.phase)
        XCTAssertEqual(6, game.calc.scores[c].gora, "mountain for 3 undertricks")
        XCTAssertEqual(0, game.calc.scores[c].pulya, "no pulya")
        XCTAssertEqual(0, game.calc.scores[whister].visty[c] ?? 0, "whists voided")
    }

    func testSurrenderWorksWithTwoWhisters() throws {
        // regression: buildTaken without a split (surrender skips step 2) used
        // to return a partial distribution the host silently rejected
        let calc = Calculation(playersCount: 3, limit: 10)
        let names = ["P0", "P1", "P2"]
        for i in 0..<3 {
            calc.scores[i].name = names[i]
        }
        let session = HostGameSession(
            seats: [SeatKind](repeating: .remote, count: 3),
            names: names,
            matchCalc: calc,
            sendToSeat: { _, _ in },
            onLocalTurn: {}
        )
        try driveToPlay(session.game, trump: 0) // Stalingrad: both opponents whist
        let game = session.game
        XCTAssertEqual(2, game.isVister.entries.filter { $0.value }.count)
        let c = game.contractor
        let info = RemoteViews.buildTableInfoFor(game, c)
        let taken = Agreements.buildTaken(info, 3) // без 3, no split
        XCTAssertEqual(10, taken.reduce(0, +), "distribution must always total ten")
        try session.onRemoteAct(c, GameMsg.Act(offer: taken))
        XCTAssertEqual(GamePhase.EndPlay, game.phase, "surrender applies unilaterally")
        for seat in 0..<3 {
            try session.confirmSeat(seat) // deal result
        }
        for seat in 0..<3 {
            try session.confirmSeat(seat) // score sheet
        }
        XCTAssertEqual(6, calc.scores[c].gora, "mountain for 3 undertricks")
        for w in game.isVister.entries.filter({ $0.value }).map({ $0.key }) {
            XCTAssertEqual(0, calc.scores[w].visty[c] ?? 0, "whists voided for every whister")
        }
    }

    func testSurrenderSurvivesSaveAndRestore() throws {
        // regression: agreedNoVists was transient, so a save on the surrender
        // result screen restored a deal that scored the whists again
        let game = try gameAtPlay()
        let c = game.contractor
        let whister = game.isVister.entries.first { $0.value }!.key
        let passer = (0...2).first { $0 != c && $0 != whister }!
        game.applyAgreement([c: 3, whister: 7, passer: 0], noVists: true)
        game.saveLast()
        let restored = try XCTUnwrap(Game.loadLast())
        restored.externalDriver = true
        XCTAssertTrue(restored.agreedNoVists, "surrender flag must survive the save")
        XCTAssertEqual(3, restored.deal.hands[c].taken, "trick counts must survive the save")
        XCTAssertEqual(6, restored.contract, "contract must survive")
        XCTAssertEqual(3, restored.playersToWait, "waiting confirms restored")
        XCTAssertEqual(0, restored.calc.scores[c].gora, "no score written yet")
        for _ in 0..<3 {
            restored.endConfirm()
            try restored.next()
        }
        XCTAssertEqual(GamePhase.ScoreView, restored.phase)
        XCTAssertEqual(6, restored.calc.scores[c].gora, "mountain only")
        XCTAssertEqual(0, restored.calc.scores[whister].visty[c] ?? 0, "whists stay voided")
    }

    func testRestMineEndsRaspasyUnilaterally() throws {
        let calc = Calculation(playersCount: 3, limit: 10)
        let names = ["P0", "P1", "P2"]
        for i in 0..<3 {
            calc.scores[i].name = names[i]
        }
        let session = HostGameSession(
            seats: [SeatKind](repeating: .remote, count: 3),
            names: names,
            matchCalc: calc,
            sendToSeat: { _, _ in },
            onLocalTurn: {}
        )
        try session.start()
        // everyone passes -> распасы
        for _ in 0..<3 {
            let pas = Game.Bid()
            pas.pas = true
            try session.onRemoteAct(session.game.turnController(), GameMsg.Act(bid: pas))
        }
        XCTAssertEqual(GameType.Raspasy, session.game.currentGameType)
        XCTAssertEqual(GamePhase.Playing, session.game.phase)
        // «остальные мои» from seat 1: instant, no confirmations
        try session.onRemoteAct(1, GameMsg.Act(restMine: true))
        XCTAssertEqual(GamePhase.EndPlay, session.game.phase)
        XCTAssertEqual(10, session.game.deal.hands[1].taken, "offerer holds every remaining trick")
        XCTAssertEqual(0, session.game.deal.hands[0].taken)
        XCTAssertEqual(0, session.game.deal.hands[2].taken)
        // through the result confirms into the score: raspasy is written
        for seat in 0..<3 {
            try session.confirmSeat(seat)
        }
        XCTAssertEqual(10, calc.scores[1].gora, "mountain for ten tricks on raspasy")
        XCTAssertTrue(calc.scores[0].pulya > 0 && calc.scores[2].pulya > 0, "non-takers write the pulya")
    }

    func testConservativeBotRule() throws {
        let game = try gameAtPlay()
        let c = game.contractor
        let whister = game.isVister.entries.first { $0.value }!.key
        let passer = (0...2).first { $0 != c && $0 != whister }!
        // at the start of play: 0 taken, 10 remaining
        // whister-bot accepts only "declarer stopped cold + I take everything"
        XCTAssertTrue(Agreements.botAccepts(whister, game, [c: 0, whister: 10, passer: 0]))
        XCTAssertFalse(Agreements.botAccepts(whister, game, [c: 6, whister: 4, passer: 0]))
        XCTAssertFalse(Agreements.botAccepts(whister, game, [c: 0, whister: 9, passer: 1]))
        // declarer-bot accepts only "I take everything remaining"
        XCTAssertTrue(Agreements.botAccepts(c, game, [c: 10, whister: 0, passer: 0]))
        XCTAssertFalse(Agreements.botAccepts(c, game, [c: 9, whister: 1, passer: 0]))
    }
}
