import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform
import PrefEngine

/// The topmost view controller, for the SDKs' full-screen presentations.
@MainActor
func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = top?.presentedViewController {
        top = presented
    }
    return top
}

/// Port of monetization/AdsManager.kt: the interstitial between a finished deal
/// and its score table. The game stays fully usable without it: no network, no
/// consent, no loaded ad or "Remove ads" all simply skip the ad and carry on.
///
/// Launch order: Google UMP consent (where required), then the App Tracking
/// Transparency prompt if the player has not decided yet, and only then the
/// Mobile Ads SDK. Declining either still gets ads (less personalised).
@MainActor
final class AdsManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdsManager()

    private var started = false
    private var sdkStarted = false
    private var loading = false
    private var interstitial: InterstitialAd?
    private var lastShownAt: TimeInterval?
    private var onClosed: (() -> Void)?

    /// True where the law asks for a way to reopen the consent choice (EEA, UK).
    @Published private(set) var privacyOptionsRequired = false

    /// Real ids come from the untracked Config/Secrets.xcconfig (Debug uses
    /// Google's public test ids). Without them there are no ads at all.
    private let interstitialId = PrefConfig.string("PrefAdMobInterstitialId")
    private let appId = PrefConfig.string("GADApplicationIdentifier")

    var enabled: Bool { interstitialId != nil && appId != nil }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Gathers consent where the law asks for it (EEA, UK), then starts the ads
    /// SDK. Safe to call on every launch: Google remembers earlier consent.
    func start() {
        guard !started, enabled, !Engagement.adFree else { return }
        started = true
        let consent = ConsentInformation.shared
        #if DEBUG
        // EEA / reset testing: PREF_UMP_EEA=1 forces the EEA form, PREF_UMP_RESET=1
        // forgets the stored choice. Simulators are test devices automatically.
        let env = ProcessInfo.processInfo.environment
        if env["PREF_UMP_RESET"] == "1" { consent.reset() }
        let parameters = RequestParameters()
        if env["PREF_UMP_EEA"] == "1" {
            let debug = DebugSettings()
            debug.geography = .EEA
            parameters.debugSettings = debug
        }
        #else
        let parameters = RequestParameters()
        #endif
        refreshPrivacyOptions()
        consent.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            #if DEBUG
            NSLog("PREFADTEST ump update error=%@ canRequestAds=%d", String(describing: error), ConsentInformation.shared.canRequestAds ? 1 : 0)
            #endif
            Task { @MainActor in
                guard let self = self else { return }
                if error != nil {
                    self.proceed() // offline or failed: still honour an earlier choice
                    return
                }
                ConsentForm.loadAndPresentIfRequired(from: topViewController()) { _ in
                    Task { @MainActor in
                        self.refreshPrivacyOptions()
                        self.proceed()
                    }
                }
            }
        }
        if consent.canRequestAds { proceed() }
    }

    /// Consent is settled: ask for tracking permission if still undecided, then
    /// start the SDK. No consent, no ATT prompt and no ads.
    private func proceed() {
        guard ConsentInformation.shared.canRequestAds else { return }
        requestTrackingIfUndecided { [weak self] in self?.startSdk() }
    }

    /// The ATT prompt only shows while the app is active, and only once: after
    /// the player's answer the status is never `.notDetermined` again.
    private func requestTrackingIfUndecided(then: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            then()
            return
        }
        guard UIApplication.shared.applicationState == .active else {
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                if let token { NotificationCenter.default.removeObserver(token) }
                MainActor.assumeIsolated { self?.requestTrackingIfUndecided(then: then) }
            }
            return
        }
        // iOS ignores a request made in the first instants after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async(execute: then)
            }
        }
    }

    /// Lets the player change their ad consent choice, from the menu.
    func showPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: topViewController()) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPrivacyOptions()
                self?.proceed()
            }
        }
    }

    /// "Remove ads" was just bought or restored: stop serving.
    func adsRemoved() {
        interstitial = nil
    }

    private func refreshPrivacyOptions() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func startSdk() {
        guard !sdkStarted, ConsentInformation.shared.canRequestAds else { return }
        sdkStarted = true
        MobileAds.shared.start { [weak self] _ in
            #if DEBUG
            NSLog("PREFADTEST sdk started")
            #endif
            Task { @MainActor in self?.preload() }
        }
    }

    private func preload() {
        guard enabled, sdkStarted, !loading, interstitial == nil, !Engagement.adFree,
              let id = interstitialId else { return }
        loading = true
        InterstitialAd.load(with: id, request: Request()) { [weak self] ad, error in
            #if DEBUG
            NSLog("PREFADTEST load ad=%d error=%@", ad == nil ? 0 : 1, String(describing: error))
            #endif
            Task { @MainActor in
                self?.interstitial = ad // nil on failure: the next deal simply has no ad
                self?.loading = false
            }
        }
    }

    /// Shows the ad when the rules say so, then calls `then` — exactly once,
    /// whether the ad ran, failed or was skipped.
    func showIfDue(dealsFinished: Int, then: @escaping () -> Void) {
        var done = false
        let finish = {
            if !done {
                done = true
                then()
            }
        }

        let ad = interstitial
        let sinceLast: Int64 = lastShownAt.map { Int64((now - $0) * 1000) } ?? Int64.max / 2
        let show = AdPolicy.shouldShow(
            adsEnabled: enabled,
            adFree: Engagement.adFree,
            dealsFinished: dealsFinished,
            adReady: ad != nil,
            msSinceLastAd: sinceLast
        )
        guard show, let ad = ad, let presenter = topViewController() else {
            preload()
            finish()
            return
        }
        interstitial = nil
        onClosed = finish
        ad.fullScreenContentDelegate = self
        ad.present(from: presenter)
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.lastShownAt = self.now
            self.closed()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.closed() }
    }

    private func closed() {
        preload()
        let callback = onClosed
        onClosed = nil
        callback?()
    }
}
