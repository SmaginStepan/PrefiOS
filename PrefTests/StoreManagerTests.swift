import XCTest
import StoreKit
import StoreKitTest
import PrefEngine
@testable import Pref

/// "Remove ads" against a local StoreKit session (Config/Pref.storekit): buy,
/// restore on a device that forgot the purchase, and refund.
@MainActor
final class StoreManagerTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Pref", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.locale = Locale(identifier: "en_US")
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        Engagement.setAdFree(false)
        StoreManager.shared.start() // listens for refunds for the rest of the run
        await StoreManager.shared.refresh()
    }

    private func waitUntil(_ what: String, _ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(condition(), what)
    }

    func testNothingOwnedByDefault() {
        XCTAssertFalse(StoreManager.shared.adFree)
        XCTAssertFalse(Engagement.adFree)
    }

    func testProductIsAvailableWithLocalizedPrice() async throws {
        let products = try await Product.products(for: [StoreManager.productId])
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.type, .nonConsumable)
    }

    func testBuyRemovesAdsAndSurvivesOfflineRelaunch() async throws {
        let result = await StoreManager.shared.buy()
        XCTAssertEqual(result, .purchased)
        XCTAssertTrue(StoreManager.shared.adFree)
        // what the next (possibly offline) launch reads before the store answers
        XCTAssertTrue(Engagement.adFree)
    }

    func testRestoreOnADeviceThatForgotThePurchase() async throws {
        try await session.buyProduct(productIdentifier: StoreManager.productId)
        Engagement.setAdFree(false) // fresh install: nothing cached locally
        await StoreManager.shared.restore()
        XCTAssertTrue(StoreManager.shared.adFree)
        XCTAssertTrue(Engagement.adFree)
    }

    func testRefundTakesAdsBack() async throws {
        let result = await StoreManager.shared.buy()
        XCTAssertEqual(result, .purchased)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: UInt(transaction.identifier))
        // delivered through Transaction.updates, no relaunch needed
        try await waitUntil("refund revokes ad-free") { !StoreManager.shared.adFree }
        XCTAssertFalse(Engagement.adFree)
    }

    func testAdPolicyHonoursThePurchase() async throws {
        _ = await StoreManager.shared.buy()
        XCTAssertFalse(AdPolicy.shouldShow(adsEnabled: true, adFree: Engagement.adFree, dealsFinished: 50,
                                           adReady: true, msSinceLastAd: 10 * 60_000))
    }
}
