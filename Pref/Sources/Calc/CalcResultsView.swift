import SwiftUI
import PrefEngine

/// Port of CalcResults.xaml.cs: the final whist totals per player.
struct CalcResultsView: View {
    let calc: Calculation
    let onClose: () -> Void

    // The original C# pattern "### ### ##0.#" used literal spaces, which ICU
    // rejects; use grouping with a space separator instead.
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("results_title"))
                .font(.system(size: 40))
                .foregroundColor(Theme.accentGold)
                .padding(.bottom, 24)
            ForEach(Array(calc.scores.enumerated()), id: \.offset) { _, score in
                HStack {
                    Text(score.name)
                        .font(.system(size: 24))
                    Spacer()
                    Text(Self.formatter.string(from: NSNumber(value: score.score)) ?? "")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.accentGold)
                }
                .padding(.vertical, 6)
            }
            Button { onClose() } label: {
                Text(L("close"))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 32)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .onAppear {
            calc.calc()
        }
    }
}
