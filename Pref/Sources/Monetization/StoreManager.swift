import Foundation
import StoreKit
import PrefEngine

/// Port of monetization/BillingManager.kt: "Remove ads", one non-consumable
/// product, paid once, owned forever.
///
/// The App Store is the source of truth. Ownership is confirmed whenever the app
/// starts or comes to the foreground and remembered locally (Engagement.adFree),
/// so an offline start stays ad-free; a refund arrives through
/// `Transaction.updates` or the next entitlement check.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    /// The in-app purchase product id to create in App Store Connect (non-consumable).
    static let productId = "remove_ads"

    enum BuyResult { case purchased, cancelled, pending, unavailable }

    @Published private(set) var adFree = Engagement.adFree
    /// The store's own formatted price (local currency), once known.
    @Published private(set) var price: String?

    private var product: Product?
    private var updates: Task<Void, Never>?

    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await loadProduct()
            await refresh()
        }
    }

    private func loadProduct() async {
        if let found = try? await Product.products(for: [Self.productId]).first {
            product = found
            price = found.displayPrice
        }
    }

    /// Re-checks what the store says the player owns.
    func refresh() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let t) = entitlement,
               t.productID == Self.productId, t.revocationDate == nil {
                owned = true
            }
        }
        apply(owned)
    }

    /// "Restore purchase": asks the App Store to sync, then re-checks.
    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    /// Starts the store's purchase sheet.
    func buy() async -> BuyResult {
        if product == nil { await loadProduct() }
        guard let product = product else { return .unavailable }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let t) = verification else { return .unavailable }
                await handle(.verified(t))
                return adFree ? .purchased : .unavailable
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .unavailable
            }
        } catch {
            return .unavailable
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result, t.productID == Self.productId else { return }
        apply(t.revocationDate == nil)
        await t.finish()
    }

    private func apply(_ owned: Bool) {
        Engagement.setAdFree(owned)
        adFree = owned
        if owned { AdsManager.shared.adsRemoved() }
    }
}
