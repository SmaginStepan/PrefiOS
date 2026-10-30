import SwiftUI
import PrefEngine

/// The rules a fresh single-player game will use (re-read each time the
/// dialog opens), shown before the game starts, with a link to change them.
private func newGameRulesSummary() -> String {
    let settings = AppSettings()
    return rulesLineTexts(settings.rules, limit: settings.limit).joined(separator: "\n")
}

struct MenuItem: View {
    let title: String
    let subtitle: String
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct MainMenuView: View {
    let hasSavedGame: Bool
    let onNewGame: () -> Void
    let onContinue: () -> Void
    let onMultiplayer: () -> Void
    let onSeason: () -> Void
    let onLearning: () -> Void
    let onCalc: () -> Void
    let onSettings: () -> Void
    let onHighScores: () -> Void
    let onDictionary: () -> Void
    let onRate: () -> Void
    let onPrivacy: () -> Void
    let onAbout: () -> Void

    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var ads: AdsManager

    @State private var showNewGame = false
    @State private var newGameRules = ""
    @State private var showRemoveAds = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Branding: title on ONE line (auto-shrinks, never wraps) with
                // the serif-italic subtitle tucked under the title's right
                // edge (not the screen's — matters on wide iPad layouts).
                VStack(alignment: .trailing, spacing: 0) {
                    Text(L("app_name"))
                        .font(.system(size: 56, design: .serif))
                        .foregroundColor(Theme.accentGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                    Text(L("menu_subtitle"))
                        .font(.system(size: 22, design: .serif))
                        .italic()
                        .kerning(6)
                        .foregroundColor(Theme.accentGold.opacity(0.75))
                }
                .padding(.bottom, 24)
                MenuItem(title: L("menu_new_game"), subtitle: L("menu_new_game_sub")) {
                    newGameRules = newGameRulesSummary() // re-read on every open
                    showNewGame = true
                }
                if hasSavedGame {
                    MenuItem(title: L("menu_continue"), subtitle: L("menu_continue_sub"), onClick: onContinue)
                }
                MenuItem(title: L("mp_menu"), subtitle: L("mp_menu_sub"), onClick: onMultiplayer)
                MenuItem(title: L("menu_season"), subtitle: L("menu_season_sub"), onClick: onSeason)
                MenuItem(title: L("menu_learning"), subtitle: L("menu_learning_sub"), onClick: onLearning)
                MenuItem(title: L("menu_pulka"), subtitle: L("menu_pulka_sub"), onClick: onCalc)
                MenuItem(title: L("menu_settings"), subtitle: L("menu_settings_sub"), onClick: onSettings)
                MenuItem(title: L("menu_records"), subtitle: L("menu_records_sub"), onClick: onHighScores)
                MenuItem(title: L("menu_dictionary"), subtitle: L("menu_dictionary_sub"), onClick: onDictionary)
                if ads.enabled && !store.adFree {
                    MenuItem(title: L("menu_remove_ads"), subtitle: L("menu_remove_ads_sub")) {
                        showRemoveAds = true
                    }
                }
                MenuItem(title: L("menu_rate"), subtitle: L("menu_rate_sub"), onClick: onRate)
                if ads.enabled && !store.adFree && ads.privacyOptionsRequired {
                    MenuItem(title: L("menu_privacy"), subtitle: L("menu_privacy_sub"), onClick: onPrivacy)
                }
                MenuItem(title: L("menu_about"), subtitle: L("menu_about_sub"), onClick: onAbout)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
        .sheet(isPresented: $showRemoveAds) {
            RemoveAdsSheet()
        }
        .alert(L("menu_new_game"), isPresented: $showNewGame) {
            Button(L("new_game_start")) { onNewGame() }
            Button(L("menu_settings")) { onSettings() }
            Button(L("close"), role: .cancel) {}
        } message: {
            Text(newGameRules)
        }
    }
}
