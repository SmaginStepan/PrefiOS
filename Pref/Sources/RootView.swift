import SwiftUI
import PrefEngine

/// Navigation routes (port of MainActivity.Routes).
enum Route: Hashable {
    case game
    case multiplayer
    case settings
    case calcRules
    case calc
    case sheet(players: Int, setup: Bool)
    case sheetGame
    case writeGame
    case results(fromGame: Bool)
    case resultsHigh
    case loadCalc
    case calcHelp
    case highScores(score: Double?)
    case dictionary
    case learning
    case about
    case gameLog
}

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            MainMenuView(
                hasSavedGame: app.game != nil,
                onNewGame: {
                    app.game = Game.create(ai1Name: L("ai_name_1"), ai2Name: L("ai_name_2"))
                    path.append(.game)
                },
                onContinue: { path.append(.game) },
                onMultiplayer: { path.append(.multiplayer) },
                onLearning: { path.append(.learning) },
                onCalc: { path.append(.calc) },
                onSettings: { path.append(.settings) },
                onHighScores: { path.append(.highScores(score: nil)) },
                onDictionary: { path.append(.dictionary) },
                onAbout: { path.append(.about) }
            )
            .navigationDestination(for: Route.self) { route in
                destination(route)
            }
        }
        .background(Theme.background)
        .onAppear {
            // Debug/screenshot hook: jump straight to a screen.
            if let autostart = ProcessInfo.processInfo.environment["PREF_AUTOSTART"] {
                switch autostart {
                case "game":
                    if app.game == nil {
                        app.game = Game.create(ai1Name: L("ai_name_1"), ai2Name: L("ai_name_2"))
                    }
                    path = [.game]
                case "sheet":
                    path = [.sheet(players: 3, setup: false)]
                case "mp":
                    path = [.multiplayer]
                case "about":
                    path = [.about]
                default:
                    break
                }
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .game:
            GameView(onShowScore: { path.append(.sheetGame) })

        case .multiplayer:
            MultiplayerView(onBack: { popBack() })

        case .settings:
            SettingsView(forCalc: false, calc: app.calc, game: app.game, onSaved: { popBack() })

        case .calcRules:
            SettingsView(forCalc: true, calc: app.calc, game: app.game, onSaved: { popBack() })

        case .calc:
            CalcMenuView(
                calc: app.calc,
                onLoad: { path.append(.loadCalc) },
                onNew3: {
                    app.calc = nil
                    path.append(.sheet(players: 3, setup: true))
                },
                onNew4: {
                    app.calc = nil
                    path.append(.sheet(players: 4, setup: true))
                },
                onContinue: {
                    let pc = app.calc?.playersCount ?? 3
                    path.append(.sheet(players: pc, setup: false))
                }
            )

        case .sheet(let players, let setup):
            CalcSheetView(
                playersCount: players,
                fromGame: false,
                startWithSetup: setup,
                onHelp: { path.append(.calcHelp) },
                onResults: { path.append(.results(fromGame: false)) },
                onResultsHighscores: { path.append(.resultsHigh) },
                onRecordGame: { path.append(.writeGame) },
                onHistory: { path.append(.gameLog) },
                onRules: { path.append(.calcRules) },
                onContinueGame: { popBack() }
            )

        case .sheetGame:
            CalcSheetView(
                playersCount: 3,
                fromGame: true,
                startWithSetup: false,
                onHelp: { path.append(.calcHelp) },
                onResults: { path.append(.results(fromGame: true)) },
                onResultsHighscores: {
                    // popUpTo(MENU) + navigate
                    path = [.resultsHigh]
                },
                onRecordGame: { path.append(.writeGame) },
                onHistory: { path.append(.gameLog) },
                onRules: { path.append(.calcRules) },
                onContinueGame: { popBack() }
            )

        case .writeGame:
            if let calc = app.calc {
                WriteGameView(calc: calc, onDone: { popBack() })
            } else {
                Color.clear
            }

        case .results(let fromGame):
            // settle the pulka of the sheet this was opened from (running game
            // vs standalone calculator) — never fall back across them
            if let calc = fromGame ? app.game?.calc : app.calc {
                CalcResultsView(calc: calc, onClose: { popBack() })
            } else {
                Color.clear
            }

        case .resultsHigh:
            if let calc = app.game?.calc {
                CalcResultsView(
                    calc: calc,
                    onClose: {
                        let score = calc.scores[0].score
                        app.game = nil
                        path = [.highScores(score: score)]
                    }
                )
            } else {
                Color.clear
            }

        case .loadCalc:
            LoadCalcView(onLoad: { created, players, limit in
                if let loaded = Calculation.load(created: created, playersCount: players, limit: limit) {
                    app.calc = loaded
                    // popUpTo(CALC) + navigate
                    if let idx = path.lastIndex(of: .calc) {
                        path = Array(path.prefix(through: idx))
                    } else {
                        path = []
                    }
                    path.append(.sheet(players: players, setup: false))
                }
            })

        case .calcHelp:
            CalcHelpView()

        case .highScores(let score):
            HighScoresView(playerScore: score, onToMenu: { path = [] })

        case .dictionary:
            DictionaryView()

        case .learning:
            LearningView(onFinished: { popBack() })

        case .about:
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            AboutView(versionName: version)

        case .gameLog:
            if let calc = app.calc ?? app.game?.calc {
                GameLogView(calc: calc)
            } else {
                Color.clear
            }
        }
    }

    private func popBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}
