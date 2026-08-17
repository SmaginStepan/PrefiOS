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
        try game.next()
        let bid6 = Game.Bid()
        bid6.contract = 6
        bid6.trump = 2 // 6 diamonds: no Stalingrad auto-whist
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
        contractBid.trump = 2
        game.setContract(contractBid)
        try game.next()
        XCTAssertEqual(GamePhase.VistNegotiations, game.phase)
        game.setVist(true)
        try game.next()
        if game.phase == .VistNegotiations {
            game.setVist(false)
            try game.next()
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
