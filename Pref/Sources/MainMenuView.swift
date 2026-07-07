import SwiftUI

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
    let onLearning: () -> Void
    let onCalc: () -> Void
    let onSettings: () -> Void
    let onHighScores: () -> Void
    let onDictionary: () -> Void
    let onAbout: () -> Void

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
                MenuItem(title: L("menu_new_game"), subtitle: L("menu_new_game_sub"), onClick: onNewGame)
                if hasSavedGame {
                    MenuItem(title: L("menu_continue"), subtitle: L("menu_continue_sub"), onClick: onContinue)
                }
                MenuItem(title: L("mp_menu"), subtitle: L("mp_menu_sub"), onClick: onMultiplayer)
                MenuItem(title: L("menu_learning"), subtitle: L("menu_learning_sub"), onClick: onLearning)
                MenuItem(title: L("menu_pulka"), subtitle: L("menu_pulka_sub"), onClick: onCalc)
                MenuItem(title: L("menu_settings"), subtitle: L("menu_settings_sub"), onClick: onSettings)
                MenuItem(title: L("menu_records"), subtitle: L("menu_records_sub"), onClick: onHighScores)
                MenuItem(title: L("menu_dictionary"), subtitle: L("menu_dictionary_sub"), onClick: onDictionary)
                MenuItem(title: L("menu_about"), subtitle: L("menu_about_sub"), onClick: onAbout)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
    }
}
