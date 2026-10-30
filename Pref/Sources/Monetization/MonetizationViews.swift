import SwiftUI
import UIKit
import PrefEngine

/// Opens the App Store's "write a review" page for this app.
@MainActor
func openReviewPage() {
    guard let id = PrefConfig.string("PrefAppStoreId"),
          let url = URL(string: "https://apps.apple.com/app/id\(id)?action=write-review") else { return }
    UIApplication.shared.open(url)
}

/// A gentle review request; it never blocks the score table underneath.
struct RateBanner: View {
    let onRate: () -> Void
    let onLater: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(L("rate_banner_text"))
                .font(.system(size: 13))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRate) { Text(L("rate_banner_rate")).font(.system(size: 13)) }
                .buttonStyle(.borderedProminent)
            Button(action: onLater) {
                Text(L("rate_banner_later"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.borderless)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .background(Theme.accentGold.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

/// The one-time "Remove ads" purchase, with restore.
struct RemoveAdsSheet: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var unavailable = false
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("menu_remove_ads"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            Text(L(store.adFree ? "ads_thanks" : "ads_dialog_text"))
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.85))
            if unavailable {
                Text(L("ads_unavailable"))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.cardRed)
            }
            VStack(spacing: 10) {
                if !store.adFree {
                    Button {
                        Task {
                            busy = true
                            unavailable = await store.buy() == .unavailable
                            busy = false
                        }
                    } label: {
                        Text(store.price.map { LF("ads_buy_fmt", $0) } ?? L("ads_buy_plain"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                HStack {
                    Button(L("close")) { dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    if !store.adFree {
                        Button {
                            Task {
                                busy = true
                                await store.restore()
                                busy = false
                            }
                        } label: { Text(L("ads_restore")) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .disabled(busy)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .presentationDetents([.height(280)])
        .task { await store.refresh() }
    }
}
