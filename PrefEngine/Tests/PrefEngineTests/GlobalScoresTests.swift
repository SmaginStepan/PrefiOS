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
}
