import SwiftUI
import PrefEngine

private enum WgStep {
    case choose, raspasy, miser, gamePlayer, gameResult
}

private struct Counter: View {
    let label: String
    let value: Int
    let onChange: (Int) -> Void
    var marker: Bool = false

    var body: some View {
        HStack {
            Text((marker ? "► " : "") + label)
                .font(.system(size: 17))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { onChange(value - 1) } label: { Text("−").font(.system(size: 24)) }
                .buttonStyle(.borderless)
            Text(String(value))
                .font(.system(size: 20))
                .frame(width: 40, alignment: .center)
            Button { onChange(value + 1) } label: { Text("+").font(.system(size: 24)) }
                .buttonStyle(.borderless)
        }
    }
}

/// Port of WriteGame.xaml.cs: record a played deal into the score sheet by hand.
struct WriteGameView: View {
    let calc: Calculation
    let onDone: () -> Void

    @State private var step = WgStep.choose
    @State private var dealer: Int
    @State private var error = false

    // Raspasy state
    @State private var raspMult = 1
    @State private var raspTaken: [Int]

    // Miser state
    @State private var miserContractor = -1
    @State private var miserTaken = 0
    @State private var halfMiser = false

    // Game state
    @State private var contract = 0
    @State private var contractor = -1
    @State private var playerTaken = 0
    @State private var vistTaken = [0, 0, 0]
    @State private var vistChecked = [false, false, false]

    init(calc: Calculation, onDone: @escaping () -> Void) {
        self.calc = calc
        self.onDone = onDone
        _dealer = State(initialValue: calc.dealer)
        _raspTaken = State(initialValue: Array(repeating: 0, count: calc.playersCount))
    }

    private var vists: [Int] {
        (0..<calc.playersCount).filter { $0 != contractor }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L("wg_title"))
                    .font(.system(size: 34))
                    .foregroundColor(Theme.accentGold)
                    .padding(.bottom, 16)

                switch step {
                case .choose: chooseStep
                case .raspasy: raspasyStep
                case .miser: miserStep
                case .gamePlayer: gamePlayerStep
                case .gameResult: gameResultStep
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
    }

    @ViewBuilder
    private var chooseStep: some View {
        Text(L("sheet_dealer_label")).font(.system(size: 18))
        ForEach(0..<calc.playersCount, id: \.self) { i in
            Button {
                dealer = i
            } label: {
                HStack {
                    Image(systemName: dealer == i ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(Theme.accentGold)
                    Text(calc.scores[i].name).font(.system(size: 17)).foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }

        let choices: [(String, Int)] = [
            (L("wg_raspasy"), 0),
            (L("wg_miser"), 1),
            (L("wg_game_6"), 6),
            (L("wg_game_7"), 7),
            (L("wg_game_8"), 8),
            (L("wg_game_9"), 9),
            (L("wg_game_10"), 10)
        ]
        ForEach(choices, id: \.1) { label, code in
            Button {
                calc.dealer = dealer
                error = false
                switch code {
                case 0:
                    raspMult = calc.currentRaspasyMultiplier
                    raspTaken = Array(repeating: 0, count: calc.playersCount)
                    step = .raspasy
                case 1:
                    miserContractor = -1
                    miserTaken = 0
                    halfMiser = false
                    step = .miser
                default:
                    contract = code
                    contractor = -1
                    step = .gamePlayer
                }
            } label: {
                Text(label)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var raspasyStep: some View {
        Text(L("wg_raspasy")).font(.system(size: 24))
        Counter(label: L("wg_multiplier"), value: raspMult, onChange: { v in
            raspMult = v < 1 ? 1 : v
        })
        ForEach(0..<calc.playersCount, id: \.self) { i in
            Counter(label: calc.scores[i].name, value: raspTaken[i], onChange: { v in
                var nv = v
                if nv < 0 { nv = 0 }
                // на прикупе в 4-х игроках можно взять максимум 2
                if i == calc.dealer && calc.playersCount == 4 && nv > 2 { nv = 2 }
                if raspTaken.reduce(0, +) - raspTaken[i] + nv <= 10 {
                    raspTaken[i] = nv
                }
            }, marker: i == calc.dealer)
        }
        if error {
            Text(L("wg_error")).foregroundColor(.red)
        }
        Button {
            if raspTaken.reduce(0, +) != 10 || raspMult < 1 {
                error = true
            } else {
                let r = Calculation.GameResult()
                r.gameType = .Raspasy
                r.dealer = calc.dealer
                for (i, v) in raspTaken.enumerated() {
                    r.taken[i] = v
                }
                r.multiplier = raspMult
                calc.writeGame(r)
                onDone()
            }
        } label: {
            Text(L("save"))
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var miserStep: some View {
        Text(L("wg_miser")).font(.system(size: 24))
        if calc.playersCount == 4 {
            Text(LF("wg_dealer_fmt", calc.scores[calc.dealer].name))
        }
        Text(L("wg_who_played")).font(.system(size: 18)).padding(.top, 8)
        ForEach(0..<calc.playersCount, id: \.self) { i in
            if !(calc.playersCount == 4 && i == calc.dealer) {
                Button {
                    miserContractor = i
                } label: {
                    HStack {
                        Image(systemName: miserContractor == i ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(Theme.accentGold)
                        Text(calc.scores[i].name).font(.system(size: 17)).foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        Counter(label: L("wg_taken"), value: miserTaken, onChange: { v in
            miserTaken = min(max(v, 0), 10)
        })
        if calc.playersCount == 4 {
            Toggle(isOn: $halfMiser) {
                Text(L("wg_half_miser"))
            }
        }
        if error {
            Text(L("wg_must_select")).foregroundColor(.red)
        }
        Button {
            if miserContractor < 0 {
                error = true
            } else {
                let r = Calculation.GameResult()
                r.gameType = .Miser
                r.dealer = calc.dealer
                r.contractor = miserContractor
                r.taken[miserContractor] = miserTaken
                r.halfWithDealer = halfMiser
                calc.writeGame(r)
                onDone()
            }
        } label: {
            Text(L("save"))
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var gamePlayerStep: some View {
        Text(gameTitle).font(.system(size: 24))
        Text(L("wg_who_played")).font(.system(size: 18)).padding(.top, 8)
        ForEach(0..<calc.playersCount, id: \.self) { i in
            if !(calc.playersCount == 4 && i == calc.dealer) {
                Button {
                    contractor = i
                    playerTaken = contract
                    vistTaken = [0, 0, 0]
                    vistChecked = [false, false, false]
                    error = false
                    step = .gameResult
                } label: {
                    Text(calc.scores[i].name)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var gameTitle: String {
        switch contract {
        case 6: return L("wg_game_6")
        case 7: return L("wg_game_7")
        case 8: return L("wg_game_8")
        case 9: return L("wg_game_9")
        default: return L("wg_game_10")
        }
    }

    @ViewBuilder
    private var gameResultStep: some View {
        Text(L("wg_contractor") + " " + calc.scores[contractor].name)
            .font(.system(size: 20))
        Counter(
            label: calc.scores[contractor].name,
            value: playerTaken,
            onChange: { v in playerTaken = min(max(v, 0), 10) },
            marker: calc.dealer == contractor
        )
        ForEach(Array(vists.enumerated()), id: \.offset) { idx, v in
            HStack {
                Toggle(isOn: Binding(
                    get: { vistChecked[idx] },
                    set: { vistChecked[idx] = $0 }
                )) {
                    EmptyView()
                }
                .labelsHidden()
                Counter(
                    label: calc.scores[v].name + " (" + L("wg_whisted") + ")",
                    value: vistTaken[idx],
                    onChange: { nv in vistTaken[idx] = min(max(nv, 0), 10) },
                    marker: calc.dealer == v
                )
            }
        }
        if error {
            Text(L("wg_error")).foregroundColor(.red)
        }
        Button {
            saveGameResult()
        } label: {
            Text(L("save"))
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 16)
    }

    private func saveGameResult() {
        // Port of GameSums.isValid
        let visters = vists.indices.filter { vistChecked[$0] }.map { vists[$0] }
        let sumOther = vistTaken.prefix(vists.count).reduce(0, +)
        let sum = playerTaken + sumOther
        var valid = (0...10).contains(playerTaken)
            && vistTaken.prefix(vists.count).allSatisfy { (0...10).contains($0) }
            && sum <= 10
        if valid {
            if sum == 10 && !visters.isEmpty {
                valid = true // сумма взяток = 10 и кто-то вистовал
            } else if sumOther == 0 && visters.isEmpty && playerTaken < contract {
                valid = true // игрок "стреляется"
            } else {
                valid = playerTaken == contract
                    && (sumOther == 0 || (playerTaken == 6 && sumOther == 2) || (playerTaken == 7 && sumOther == 1))
                    && visters.isEmpty
            }
        }
        if valid && visters.count > 2 {
            valid = false
        }
        if valid && visters.count == 2 && calc.playersCount == 4 && visters.contains(calc.dealer) {
            valid = false
        }

        if !valid {
            error = true
        } else {
            let r = Calculation.GameResult()
            r.gameType = .Normal
            r.contract = contract
            r.contractor = contractor
            r.dealer = calc.dealer
            r.visters = visters
            r.taken[contractor] = playerTaken
            for i in vists.indices {
                r.taken[vists[i]] = vistTaken[i]
            }
            calc.writeGame(r)
            onDone()
        }
    }
}
