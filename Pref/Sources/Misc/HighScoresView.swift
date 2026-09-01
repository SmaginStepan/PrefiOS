import SwiftUI
import PrefEngine

// The seeded leaderboard names are stored in Russian; outside the Russian
// locale they are shown transliterated (QA M-02).
private let seededNameTranslit: [String: String] = [
    "Эйнштейн": "Einstein",
    "Да Винчи": "Da Vinci",
    "Перельман": "Perelman",
    "Вован": "Vovan",
    "Настасья": "Nastasya",
    "Алексей": "Alexey",
    "Андрей": "Andrey",
    "Григорий": "Grigory",
    "Ирина": "Irina",
]

/// The global leaderboard (ScoreServer): the last cached board shows
/// immediately — the classic seeded names before the first fetch — and a
/// background sync flushes queued scores and refreshes the list. The game
/// itself stays fully offline; scores queue until the network allows.
struct HighScoresView: View {
    let playerScore: Double?
    let onToMenu: () -> Void

    @EnvironmentObject private var app: AppState
    @State private var rows = GlobalScores.cached()
    @State private var syncTick = 0
    @State private var showNewRecord = false
    @State private var playerName = AppSettings().isDefaultPlayerName
        ? L("default_player_name") : AppSettings().playerName
    @State private var appeared = false

    private let myId = AppSettings().playerId

    private var isRussian: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("ru") == true
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.usesGroupingSeparator = false
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L("hs_title"))
                    .font(.system(size: 40))
                    .foregroundColor(Theme.accentGold)
                    .padding(.bottom, 24)

                if showNewRecord {
                    Text(L("hs_new_record")).font(.system(size: 18))
                    TextField("", text: $playerName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 8)
                    Button {
                        let settings = AppSettings()
                        settings.playerName = playerName
                        app.game?.calc.scores[0].name = playerName
                        GlobalScores.enqueue(name: playerName, score: playerScore ?? 0.0)
                        showNewRecord = false
                        syncTick += 1
                    } label: {
                        Text(L("save"))
                    }
                    .buttonStyle(.borderedProminent)
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    let mine = row.playerId == myId
                    HStack {
                        Text(isRussian ? row.name
                            : (seededNameTranslit[row.name] ?? row.name))
                            .font(.system(size: 22))
                            .foregroundColor(mine ? Color(red: 1, green: 0xEB / 255.0, blue: 0x3B / 255.0) : .gray)
                        Spacer()
                        Text(Self.formatter.string(from: NSNumber(value: row.score)) ?? "")
                            .font(.system(size: 22))
                            .foregroundColor(mine ? Color(red: 1, green: 0xEB / 255.0, blue: 0x3B / 255.0) : .gray)
                    }
                    .padding(.vertical, 4)
                }

                Button { onToMenu() } label: {
                    Text(L("hs_to_menu"))
                }
                .buttonStyle(.bordered)
                .padding(.top, 24)
            }
            .padding(24)
        }
        .background(Theme.background)
        .onAppear {
            if !appeared {
                appeared = true
                // a winning score that beats the visible board asks for the
                // name first; anything else queues right away under the
                // current name
                if let playerScore = playerScore, playerScore >= GlobalScores.minScore,
                   rows.count < 10 || playerScore * 10 > Double(rows.map(\.score10).min() ?? 0) {
                    showNewRecord = true
                } else if let playerScore = playerScore, playerScore >= GlobalScores.minScore {
                    GlobalScores.enqueue(name: playerName, score: playerScore)
                    syncTick += 1
                } else {
                    syncTick += 1
                }
            }
        }
        .task(id: syncTick) {
            if syncTick > 0 {
                let fresh = await GlobalScores.sync()
                rows = fresh ?? GlobalScores.cached()
            }
        }
    }
}
