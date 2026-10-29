import SwiftUI
import PrefEngine

/// Port of PrefApp/App.xaml.cs: holds the current game and score sheet,
/// loads them on launch and saves them when the app goes to background.
///
/// A normal single-player game and a season run are kept side by side, so
/// playing one never overwrites the other. `game` is whichever the player is in
/// right now (`seasonMode`); the main menu always switches back to the normal one.
final class AppState: ObservableObject {
    @Published var normalGame: Game?
    @Published var seasonGame: Game?
    @Published var seasonMode = false
    @Published var calc: Calculation?

    var game: Game? {
        get { seasonMode ? seasonGame : normalGame }
        set {
            if seasonMode {
                seasonGame = newValue
            } else {
                normalGame = newValue
            }
        }
    }

    init() {
        let filesDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        PrefStorage.initialize(filesDir: filesDir)
        calc = Calculation.loadLast()
        normalGame = Game.loadLast()
        seasonGame = Game.loadSeason()
        // the score credentials ship in the binary but not in the public repo:
        // they arrive through Info.plist from the untracked Secrets.xcconfig
        ScoreClient.configure(
            apiKey: PrefConfig.string("PrefScoreApiKey"),
            secret: PrefConfig.string("PrefScoreSecret")
        )
        // scores finished offline reach the global board on the next launch
        Task.detached(priority: .utility) {
            await GlobalScores.flushPending()
        }
    }

    func saveAll() {
        calc?.saveLast()
        normalGame?.saveLast()
        seasonGame?.saveLast()
    }
}

@main
struct PrefApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .tint(Theme.accentGold)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                app.saveAll()
            }
        }
    }
}
