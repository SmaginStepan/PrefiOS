import SwiftUI
import PrefEngine

/// Port of GameLog.xaml.cs: chronological list of recorded deals.
struct GameLogView: View {
    let calc: Calculation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L("log_title"))
                    .font(.system(size: 40))
                    .foregroundColor(Theme.accentGold)
                    .padding(.bottom, 16)
                ForEach(Array(calc.gameLog.reversed().enumerated()), id: \.offset) { _, game in
                    Text(GameTexts.resultText(game, calc))
                        .font(.system(size: 15))
                        .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Theme.background)
    }
}
