import SwiftUI
import PrefEngine

/// Port of LoadCalc.xaml.cs: pick a previously saved score sheet.
struct LoadCalcView: View {
    let onLoad: (Int64, Int, Int) -> Void

    @State private var calcs: [CalcList.Calc] = []

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L("load_title"))
                    .font(.system(size: 40))
                    .foregroundColor(Theme.accentGold)
                    .padding(.bottom, 24)
                ForEach(Array(calcs.enumerated()), id: \.offset) { _, calc in
                    Button {
                        onLoad(calc.created, calc.playersCount, calc.limit)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LF("load_from", Self.dateFormatter.string(from: Date(timeIntervalSince1970: Double(calc.created) / 1000.0))))
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text(LF("load_players_fmt", calc.playersCount, calc.limit))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(Theme.background)
        .onAppear {
            let list = CalcList()
            list.load()
            calcs = list.calcs
        }
    }
}
