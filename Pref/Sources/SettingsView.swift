import SwiftUI
import PrefEngine

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 18))
            .foregroundColor(.white.opacity(0.6))
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}

private struct RadioGroup<T: Hashable>: View {
    let options: [(T, String)]
    let selected: T
    let onSelect: (T) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    onSelect(value)
                } label: {
                    HStack {
                        Image(systemName: value == selected ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(Theme.accentGold)
                        Text(label)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Port of Settings.xaml(.cs). Two modes:
///  - forCalc = false: app settings (player name, limit, default rules)
///  - forCalc = true: rules of the current score sheet (calc)
struct SettingsView: View {
    let forCalc: Bool
    let calc: Calculation?
    let game: Game?
    let onSaved: () -> Void

    private let settings: AppSettings?
    private let sourceRules: GameRules

    @State private var playerName: String
    @State private var limitText: String
    @State private var gameType: RulesGameType
    @State private var raspProgression: RaspasyProgression
    @State private var raspExit: RaspasyExit
    @State private var miserRaspExit: Bool
    @State private var consolation: ConsolationType
    @State private var vistType: VistType
    @State private var prikupConsolation: Bool
    // hidden values driven by the game-type presets
    @State private var ending: EndingType
    @State private var scoring: ScoreType
    @State private var consolationBonus: ConsolationSum

    init(forCalc: Bool, calc: Calculation?, game: Game?, onSaved: @escaping () -> Void) {
        self.forCalc = forCalc
        self.calc = calc
        self.game = game
        self.onSaved = onSaved
        let settings = forCalc ? nil : AppSettings()
        self.settings = settings
        let sourceRules: GameRules
        if forCalc, let calc = calc {
            sourceRules = calc.rules
        } else {
            sourceRules = settings?.rules ?? GameRules()
        }
        self.sourceRules = sourceRules

        _playerName = State(initialValue: settings?.playerName ?? "")
        _limitText = State(initialValue: String(settings?.limit ?? 40))
        _gameType = State(initialValue: sourceRules.gameType)
        _raspProgression = State(initialValue: sourceRules.raspasyProgression)
        _raspExit = State(initialValue: sourceRules.raspasyExit)
        _miserRaspExit = State(initialValue: sourceRules.miserRaspExit)
        _consolation = State(initialValue: sourceRules.consolation)
        _vistType = State(initialValue: sourceRules.vist)
        _prikupConsolation = State(initialValue: sourceRules.prikupConsolation)
        _ending = State(initialValue: sourceRules.ending)
        _scoring = State(initialValue: sourceRules.scoring)
        _consolationBonus = State(initialValue: sourceRules.consolationBonus)
    }

    private func applyGameTypePreset(_ type: RulesGameType) {
        gameType = type
        switch type {
        case .Sochy:
            vistType = .FullResponsibility
            consolation = .Zlob
            ending = .Each
            scoring = .Normal
            consolationBonus = .Normal
        case .Leningrad:
            vistType = .HalfResponsibility
            consolation = .Gentlemen
            ending = .Sum
            scoring = .Leningrad
            consolationBonus = .Normal
        case .Rostov:
            raspProgression = .NoProgression1
            vistType = .HalfResponsibility
            consolation = .Gentlemen
            ending = .Each
            scoring = .Normal
            consolationBonus = .Max10
        }
    }

    private func save() {
        let rules = GameRules()
        rules.gameType = gameType
        rules.raspasyProgression = raspProgression
        rules.raspasyExit = raspExit
        rules.miserRaspExit = miserRaspExit
        rules.consolation = consolation
        rules.vist = vistType
        rules.prikupConsolation = prikupConsolation
        rules.ending = ending
        rules.scoring = scoring
        rules.consolationBonus = consolationBonus
        rules.vistTakeOnRaspas = sourceRules.vistTakeOnRaspas
        rules.stalindgrad = sourceRules.stalindgrad
        if let settings = settings {
            settings.rules = rules
            if let limit = Int(limitText) {
                settings.limit = limit
            }
            if settings.playerName != playerName && !playerName.trimmingCharacters(in: .whitespaces).isEmpty {
                settings.playerName = playerName
                game?.calc.scores[0].name = playerName
            }
        }
        if forCalc, let calc = calc {
            calc.rules = rules
        }
        onSaved()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L(forCalc ? "rules_title" : "settings_title"))
                    .font(.system(size: 40))
                    .foregroundColor(Theme.accentGold)

                if !forCalc {
                    SectionLabel(text: L("settings_language"))
                    // On iOS the app language is chosen in the system Settings
                    // (per-app language, enabled by CFBundleLocalizations).
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("English / Русский / Español…")
                            .font(.system(size: 17))
                    }
                    .padding(.vertical, 4)

                    SectionLabel(text: L("settings_player_name"))
                    TextField("", text: $playerName)
                        .textFieldStyle(.roundedBorder)
                    SectionLabel(text: L("settings_limit"))
                    TextField("", text: $limitText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                SectionLabel(text: L("settings_game_type"))
                RadioGroup(
                    options: [
                        (RulesGameType.Sochy, L("settings_game_sochy")),
                        (RulesGameType.Leningrad, L("settings_game_leningrad")),
                        (RulesGameType.Rostov, L("settings_game_rostov"))
                    ],
                    selected: gameType,
                    onSelect: { applyGameTypePreset($0) }
                )

                SectionLabel(text: L("settings_raspasy"))
                if gameType != .Rostov {
                    RadioGroup(
                        options: [
                            (RaspasyProgression.NoProgression1, L("settings_progression_none")),
                            (RaspasyProgression.Arifm1233, L("settings_progression_arifm")),
                            (RaspasyProgression.Geom1244, L("settings_progression_geom"))
                        ],
                        selected: raspProgression,
                        onSelect: { raspProgression = $0 }
                    )
                }

                SectionLabel(text: L("settings_exit"))
                RadioGroup(
                    options: [
                        (RaspasyExit.Easy6, L("settings_exit_easy")),
                        (RaspasyExit.Med677, L("settings_exit_med")),
                        (RaspasyExit.Hard678, L("settings_exit_hard"))
                    ],
                    selected: raspExit,
                    onSelect: { raspExit = $0 }
                )

                Toggle(isOn: $miserRaspExit) {
                    Text(L("settings_miser_exit")).font(.system(size: 17))
                }
                .padding(.vertical, 4)

                SectionLabel(text: L("settings_vist"))
                RadioGroup(
                    options: [
                        (ConsolationType.Zlob, L("settings_consolation_zlob")),
                        (ConsolationType.Gentlemen, L("settings_consolation_gentlemen"))
                    ],
                    selected: consolation,
                    onSelect: { consolation = $0 }
                )
                RadioGroup(
                    options: [
                        (VistType.FullResponsibility, L("settings_vist_full")),
                        (VistType.HalfResponsibility, L("settings_vist_half"))
                    ],
                    selected: vistType,
                    onSelect: { vistType = $0 }
                )

                Toggle(isOn: $prikupConsolation) {
                    Text(L("settings_prikup_consolation")).font(.system(size: 17))
                }
                .padding(.vertical, 4)

                Button {
                    save()
                } label: {
                    Text(L("save"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical, 24)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
    }
}
