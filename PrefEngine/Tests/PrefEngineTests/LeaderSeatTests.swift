import XCTest
@testable import PrefEngine

/// The lead marker (first hand until play starts, then the round's leader) and
/// the ">" turn marker. Port of the Android LeaderSeatTest and TurnMarkerTest.
final class LeaderSeatTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pref-leader-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        PrefStorage.initialize(filesDir: dir)
    }

    private func game(dealer: Int) -> Game {
        let g = Game.create()
        g.calc.dealer = dealer
        return g
    }

    func testFirstHandIsLeftOfTheDealerBeforePlay() {
        for dealer in 0...2 {
            let g = game(dealer: dealer)
            let phases: [GamePhase] = [
                .Negotiations, .VistNegotiations, .PrikupOpened,
                .Discarding, .GameChoose, .OpeningChoose,
            ]
            for phase in phases {
                g.phase = phase
                XCTAssertEqual((dealer + 1) % 3, g.leaderSeat(), "dealer \(dealer), \(phase)")
            }
        }
    }

    func testTrickLeaderStaysMarkedWhileOthersPlay() {
        let g = game(dealer: 2)
        g.phase = .Playing
        g.firstMovePerformer = 1 // seat 1 led this trick
        g.playerInTurn = 0       // and it is seat 0's turn now
        XCTAssertEqual(1, g.leaderSeat())
    }

    func testBetweenTricksTheNextLeaderIsMarked() {
        let g = game(dealer: 0)
        g.phase = .Playing
        g.firstMovePerformer = -1 // nobody has played to the new trick yet
        g.playerInTurn = 2        // the previous taker leads
        XCTAssertEqual(2, g.leaderSeat())
    }

    func testFinishedTrickMarksTheTaker() {
        let g = game(dealer: 0)
        g.currentGameType = .Normal
        g.phase = .EndTurn
        g.firstMovePerformer = 1
        g.playerInTurn = 1
        g.playerToTake = 2
        XCTAssertEqual(2, g.leaderSeat())
    }

    func testAllPassTalonTricksStartWithTheFirstHand() {
        // regression (found in a live multiplayer test on Android): the trick
        // that follows the first review opens a talon card, and then the first
        // hand moves first, so that review must not point at the taker
        let g = game(dealer: 0) // first hand = seat 1
        g.phase = .EndTurn
        g.currentGameType = .Raspasy
        g.playerToTake = 2
        XCTAssertEqual(1, g.leaderSeat(), "review of trick 1")
        g.deal.hands[0].taken = 1 // trick 2 on view: trick 3 has no talon card
        XCTAssertEqual(2, g.leaderSeat(), "review of trick 2")
        g.deal.hands[0].taken = 5
        XCTAssertEqual(2, g.leaderSeat(), "a late review")
    }

    func testRostovAllPassHasNoTalonCardSoTheTakerLeads() {
        // Moscow/Rostov all-pass play never opens talon cards, so every review
        // points at the taker, even right after the first trick
        let g = game(dealer: 0)
        g.calc.rules.gameType = .Rostov
        g.phase = .EndTurn
        g.currentGameType = .Raspasy
        g.playerToTake = 2
        XCTAssertEqual(2, g.leaderSeat(), "review of trick 1")
    }

    func testResultAndScoreScreensHaveNoLeader() {
        let g = game(dealer: 0)
        for phase in [GamePhase.EndPlay, .ScoreView, .Ended, .NotStarted] {
            g.phase = phase
            XCTAssertEqual(-1, g.leaderSeat(), "\(phase)")
        }
    }

    // MARK: - real all-pass deals through the engine

    /// Plays whole all-pass deals and checks, at EVERY trick review, that the
    /// marker agrees with who actually moves first once the review is
    /// confirmed — the invariant the hand-set cases above only sample.
    private func playAllPassDeals(rules: RulesGameType, deals: Int) throws -> Int {
        var reviews = 0
        for _ in 0..<deals {
            let g = Game.create()
            g.calc.rules.gameType = rules
            g.externalDriver = true
            try g.next()
            for _ in 0..<3 {
                let pas = Game.Bid()
                pas.pas = true
                g.makeBid(pas)
                try g.next()
            }
            XCTAssertEqual(.Raspasy, g.currentGameType)

            var steps = 0
            while g.phase == .Playing || g.phase == .EndTurn, steps < 200 {
                steps += 1
                if g.phase == .Playing {
                    // the leader stays fixed while the other two play to the trick
                    if g.firstMovePerformer >= 0 {
                        XCTAssertEqual(g.firstMovePerformer, g.leaderSeat(), "mid-trick leader")
                    }
                    guard let move = g.getAllowedMoves().first else {
                        XCTFail("no legal move")
                        return reviews
                    }
                    g.playCard(move)
                    try g.next()
                } else {
                    let marked = g.leaderSeat()
                    let nextTrickOpensTalon = rules != .Rostov && g.deal.totalTaken + 1 < 2
                    while g.phase == .EndTurn {
                        g.turnClose()
                        try g.next()
                    }
                    reviews += 1
                    if g.phase == .Playing {
                        XCTAssertEqual(g.playerInTurn, marked,
                                       "review marker must name who really leads next (\(rules))")
                        if nextTrickOpensTalon {
                            XCTAssertEqual(g.getFirstPlayer(), marked, "talon trick: first hand moves first")
                        }
                    }
                }
            }
        }
        return reviews
    }

    func testEveryReviewOfRealAllPassDealsNamesTheNextLeader() throws {
        for rules in [RulesGameType.Sochy, .Leningrad, .Rostov] {
            let reviews = try playAllPassDeals(rules: rules, deals: 25)
            XCTAssertEqual(25 * 10, reviews, "ten reviews per deal (\(rules))")
        }
    }

    // MARK: - the ">" turn marker

    private func info(_ phase: GamePhase, inTurn: Int = 1, toTake: Int = 2, contractor: Int = 0) -> TableInfo {
        var i = TableInfo()
        i.phase = phase
        i.playerInTurn = inTurn
        i.playerToTake = toTake
        i.contractor = contractor
        return i
    }

    func testMarkerFollowsThePlayerInTurnWhilePlaying() {
        XCTAssertEqual(1, info(.Playing).turnMarker())
        XCTAssertEqual(1, info(.Negotiations).turnMarker())
    }

    func testMarkerPointsAtTheLeaderInTheTrickReview() {
        var i = info(.EndTurn, inTurn: 1, toTake: 2)
        i.leader = 1
        XCTAssertEqual(1, i.turnMarker())
        // an older host sends no leader: fall back to the taker
        i.leader = -1
        XCTAssertEqual(2, i.turnMarker())
    }

    func testMarkerPointsAtTheContractorAtTheOpenedTalon() {
        XCTAssertEqual(2, info(.PrikupOpened, contractor: 2).turnMarker())
    }

    func testResultAndScoreScreensShowNoMarker() {
        XCTAssertEqual(-1, info(.EndPlay).turnMarker())
        XCTAssertEqual(-1, info(.ScoreView).turnMarker())
        XCTAssertEqual(-1, info(.Ended).turnMarker())
        XCTAssertEqual(-1, info(.NotStarted).turnMarker())
    }

    func testAnimatingPlayerOverridesEverything() {
        XCTAssertEqual(0, info(.Playing).turnMarker(override: 0))
        XCTAssertEqual(1, info(.EndTurn, toTake: 2).turnMarker(override: 1))
        XCTAssertEqual(2, info(.EndPlay).turnMarker(override: 2))
        // a table-level animation (raspasy talon card, player -1) changes nothing
        XCTAssertEqual(1, info(.Playing).turnMarker(override: -1))
    }

    // MARK: - wire

    func testLeaderSurvivesTheWireAndOlderHostsDecodeToNone() throws {
        var i = info(.Playing)
        i.leader = 2
        let json = try WireJSON.encodeToString(i)
        XCTAssertEqual(2, try WireJSON.decodeFromString(TableInfo.self, json).leader)
        // a host that predates the field simply omits it
        let old = json.replacingOccurrences(of: "\"leader\":2,", with: "")
        XCTAssertFalse(old.contains("leader"))
        XCTAssertEqual(-1, try WireJSON.decodeFromString(TableInfo.self, old).leader)
    }

    func testViewerRelativeLeaderIsRotatedLikeEverySeatField() {
        let g = game(dealer: 0)
        g.phase = .Negotiations // first hand = seat 1
        XCTAssertEqual(1, RemoteViews.buildTableInfoFor(g, 0).leader)
        XCTAssertEqual(0, RemoteViews.buildTableInfoFor(g, 1).leader)
        XCTAssertEqual(2, RemoteViews.buildTableInfoFor(g, 2).leader)
        g.phase = .EndPlay
        XCTAssertEqual(-1, RemoteViews.buildTableInfoFor(g, 1).leader, "no leader stays -1, not rotated")
    }
}
