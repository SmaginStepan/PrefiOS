import SwiftUI
import PrefEngine

/// Port of HighScores.xaml.cs.
struct HighScoresView: View {
    let playerScore: Double?
    let onToMenu: () -> Void

    @EnvironmentObject private var app: AppState
    @State private var table = HighScoresTable.load()
    @State private var version = 0
    @State private var showNewRecord = false
    @State private var playerName = AppSettings().playerName
    @State private var appeared = false

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
                        table.addScore(playerName, playerScore ?? 0.0)
                        let settings = AppSettings()
                        settings.playerName = playerName
                        app.game?.calc.scores[0].name = playerName
                        table.save()
                        showNewRecord = false
                        version += 1
                    } label: {
                        Text(L("save"))
                    }
                    .buttonStyle(.borderedProminent)
                }

                let _ = version
                ForEach(Array(table.scores.enumerated()), id: \.offset) { _, score in
                    HStack {
                        Text(score.playerName)
                            .font(.system(size: 22))
                            .foregroundColor(score.lastAdded ? Color(red: 1, green: 0xEB / 255.0, blue: 0x3B / 255.0) : .gray)
                        Spacer()
                        Text(Self.formatter.string(from: NSNumber(value: score.score)) ?? "")
                            .font(.system(size: 22))
                            .foregroundColor(score.lastAdded ? Color(red: 1, green: 0xEB / 255.0, blue: 0x3B / 255.0) : .gray)
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
                if let playerScore = playerScore, table.minScore < playerScore {
                    showNewRecord = true
                }
            }
        }
    }
}
