import SwiftUI
import PrefEngine

/// Port of PrefApp/App.xaml.cs: holds the current game and score sheet,
/// loads them on launch and saves them when the app goes to background.
final class AppState: ObservableObject {
    @Published var game: Game?
    @Published var calc: Calculation?

    init() {
        let filesDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        PrefStorage.initialize(filesDir: filesDir)
        calc = Calculation.loadLast()
        game = Game.loadLast()
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
        game?.saveLast()
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
