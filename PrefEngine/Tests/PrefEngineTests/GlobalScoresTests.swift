import XCTest
@testable import PrefEngine

/// Global leaderboard: signature scheme, seeded fallback, queue filtering.
/// Port of the Android GlobalScoresTest / AppSettingsTest.
final class GlobalScoresTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pref-scores-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        PrefStorage.initialize(filesDir: dir)
    }

    func testSignatureMatchesServerScheme() {
        // reference values computed independently (.NET HMACSHA256)
        let body = Data(#"{"player_id":"p1","name":"Step","score":123,"device_ts":1700000000}"#.utf8)
        let payload = ScoreClient.signaturePayload(
            "1700000000", "post", "/v1/pref/boards/alltime/scores", body
        )
        XCTAssertEqual(
            "1700000000\nPOST\n/v1/pref/boards/alltime/scores\n"
                + "6da3de2babbd13f125d4e8525247dd57e4170fbe0797b66797e8a91ed3741511",
            payload
        )
        XCTAssertEqual(
            "30e4698209eaa50fa93423f058017f3c6f12bf03b049cabb98601f9796a9a12f",
            ScoreClient.sign("s3cret", payload)
        )
    }

    func testFallbackShowsTheClassicTable() {
        let rows = GlobalScores.cached() // nothing fetched yet
        XCTAssertEqual(10, rows.count)
        XCTAssertEqual("Эйнштейн", rows[0].name)
        XCTAssertEqual(1000.0, rows[0].score)
        XCTAssertEqual(0.0, rows[9].score)
    }

    func testSmallAndLosingScoresNeverQueue() {
        GlobalScores.enqueue(name: "Loser", score: -12.5)
        GlobalScores.enqueue(name: "Small", score: 9.9) // below the 10-whist minimum
        let before = PrefStorage.readText("pending_scores.json") ?? ""
        XCTAssertTrue(!before.contains("Loser") && !before.contains("Small"))
        GlobalScores.enqueue(name: "Winner", score: 42.5) // x10 rounding keeps the half-whist
        let pending = PrefStorage.readText("pending_scores.json") ?? ""
        XCTAssertTrue(pending.contains("Winner"))
        XCTAssertTrue(pending.contains("425"))
    }

    func testPoolLimitIsClampedToTenThroughHundred() {
        XCTAssertEqual(40, AppSettings().limit) // default untouched
        XCTAssertEqual(10, AppSettings.clampLimit(3))
        XCTAssertEqual(10, AppSettings.clampLimit(4))
        XCTAssertEqual(40, AppSettings.clampLimit(40))
        XCTAssertEqual(100, AppSettings.clampLimit(250))
        let s = AppSettings()
        s.limit = 3
        XCTAssertEqual(10, AppSettings().limit)
        s.limit = 500
        XCTAssertEqual(100, AppSettings().limit)
        s.limit = 40
        XCTAssertEqual(40, AppSettings().limit)
    }

    func testRoundingMatchesKotlinRoundToLong() {
        // ties go toward +infinity, not away from zero
        XCTAssertEqual(-42, roundToLongHalfUp(-42.5))
        XCTAssertEqual(43, roundToLongHalfUp(42.5))
        XCTAssertEqual(-43, roundToLongHalfUp(-42.6))
        XCTAssertEqual(-42, roundToLongHalfUp(-42.4))
        XCTAssertEqual(0, roundToLongHalfUp(0.49999999999999994))
        XCTAssertEqual(425, roundToLongHalfUp(42.5 * 10))
    }

    func testClientWithoutCredentialsDegradesGracefully() async {
        ScoreClient.configure(apiKey: nil, secret: nil)
        XCTAssertFalse(ScoreClient.isConfigured)
        let top = await ScoreClient.fetchTop()
        XCTAssertNil(top, "no credentials: reads fail soft, the app falls back to the cached board")
        let season = await ScoreClient.fetchSeason()
        XCTAssertNil(season)
        let outcome = await ScoreClient.submit(playerId: "p", name: "n", score10: 1, deviceTs: 1)
        XCTAssertEqual(.retry, outcome, "no credentials: the queued score stays queued")
    }

    /// Live server check. Needs the real credentials in the environment:
    ///   PREF_SCORE_API_KEY=… PREF_SCORE_SECRET=… swift test --filter testLiveScoreServer
    func testLiveScoreServer() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let key = env["PREF_SCORE_API_KEY"], let secret = env["PREF_SCORE_SECRET"] else {
            throw XCTSkip("live test; set PREF_SCORE_API_KEY and PREF_SCORE_SECRET")
        }
        ScoreClient.configure(apiKey: key, secret: secret)
        defer { ScoreClient.configure(apiKey: nil, secret: nil) }

        let fetchedTop = await ScoreClient.fetchTop(limit: 10)
        let top = try XCTUnwrap(fetchedTop)
        XCTAssertEqual(10, top.count)

        let fetchedSeason = await ScoreClient.fetchSeason()
        let season = try XCTUnwrap(fetchedSeason, "a season must be running")
        XCTAssertFalse(season.seed.isEmpty)
        XCTAssertGreaterThan(season.endsAt, season.startsAt)
        print("LIVE season \(season.seasonId) seed \(season.seed)")

        // an absurd score authenticates (HTTP 200 + accepted:false) and is
        // rejected on its value: nothing is recorded on either board
        let absurd: Int64 = 99_999_999
        let a = await ScoreClient.submit(playerId: "ios-sig-selftest", name: "SigTest", score10: absurd, deviceTs: Int64(Date().timeIntervalSince1970))
        XCTAssertEqual(.drop, a, "alltime: signed write authenticated, value rejected")
        let b = await ScoreClient.submit(playerId: "ios-sig-selftest", name: "SigTest", score10: absurd, deviceTs: Int64(Date().timeIntervalSince1970), board: "total:\(season.seasonId)")
        XCTAssertEqual(.drop, b, "season board path (with the colon) signs and authenticates too")
        let board = await ScoreClient.fetchTop(limit: 10, board: "total:\(season.seasonId)")
        XCTAssertNotNil(board, "the season board is readable")
    }
}
