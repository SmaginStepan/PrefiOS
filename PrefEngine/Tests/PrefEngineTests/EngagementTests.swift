import XCTest
@testable import PrefEngine

final class EngagementTests: XCTestCase {
    override func setUp() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("engagement-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        PrefStorage.initialize(filesDir: dir)
    }

    private func show(ads: Bool = true, free: Bool = false, deals: Int = 11,
                      ready: Bool = true, gap: Int64 = 45_000) -> Bool {
        AdPolicy.shouldShow(adsEnabled: ads, adFree: free, dealsFinished: deals,
                            adReady: ready, msSinceLastAd: gap)
    }

    func testFirstTenDealsAreAdFreeThenAdsStart() {
        for d in 1...10 { XCTAssertFalse(show(deals: d), "deal \(d)") }
        XCTAssertTrue(show(deals: 11))
        XCTAssertTrue(show(deals: 500))
    }

    func testEveryConditionIsRequired() {
        XCTAssertFalse(show(ads: false))
        XCTAssertFalse(show(free: true))
        XCTAssertFalse(show(ready: false))
    }

    func testFortyFiveSecondGap() {
        XCTAssertFalse(show(gap: 44_999))
        XCTAssertTrue(show(gap: 45_000))
        // nothing shown yet this launch: the gap is effectively unlimited
        XCTAssertTrue(show(gap: Int64.max / 2))
    }

    func testDealCounterPersistsAndStartsAtOne() {
        XCTAssertEqual(Engagement.state().dealsFinished, 0)
        XCTAssertEqual(Engagement.dealFinished(), 1)
        XCTAssertEqual(Engagement.dealFinished(), 2)
        XCTAssertEqual(Engagement.state().dealsFinished, 2)
    }

    func testRateBannerEveryTenthDealUntilRated() {
        var due: [Int] = []
        for _ in 1...30 {
            let n = Engagement.dealFinished()
            if Engagement.rateBannerDue() { due.append(n) }
        }
        XCTAssertEqual(due, [10, 20, 30])
        Engagement.markRated()
        for _ in 1...10 { _ = Engagement.dealFinished() }
        XCTAssertFalse(Engagement.rateBannerDue())
    }

    func testAdFreeSurvivesRestartAndCanBeRevoked() {
        XCTAssertFalse(Engagement.adFree)
        Engagement.setAdFree(true)
        XCTAssertTrue(Engagement.adFree)
        Engagement.setAdFree(false) // refund
        XCTAssertFalse(Engagement.adFree)
    }

    func testCorruptFileFallsBackToDefaults() {
        PrefStorage.writeText("engagement.json", "{not json")
        XCTAssertEqual(Engagement.state().dealsFinished, 0)
        XCTAssertFalse(Engagement.adFree)
    }
}
