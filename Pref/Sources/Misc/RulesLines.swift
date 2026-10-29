import PrefEngine

/// The rules of a game as plain "label: value" lines. `full` adds the remaining
/// switches (a season randomizes all of them). Port of Android's RulesLines.
func rulesLineTexts(_ rules: GameRules, limit: Int, full: Bool = false) -> [String] {
    func line(_ label: String, _ value: String) -> String {
        label.hasSuffix(":") ? "\(label) \(value)" : "\(label): \(value)"
    }
    let type: String
    switch rules.gameType {
    case .Sochy: type = L("settings_game_sochy")
    case .Leningrad: type = L("settings_game_leningrad")
    case .Rostov: type = L("settings_game_rostov")
    }
    let progression: String
    switch rules.raspasyProgression {
    case .NoProgression1: progression = L("settings_progression_none")
    case .Arifm1233: progression = L("settings_progression_arifm")
    case .Geom1244: progression = L("settings_progression_geom")
    }
    let exit: String
    switch rules.raspasyExit {
    case .Easy6: exit = L("settings_exit_easy")
    case .Med677: exit = L("settings_exit_med")
    case .Hard678: exit = L("settings_exit_hard")
    }
    var lines = [
        line(L("settings_game_type"), type),
        line(L("settings_limit"), String(limit)),
        line(L("settings_vist"), L(rules.vist == .FullResponsibility ? "settings_vist_full" : "settings_vist_half")),
        line(L("settings_raspasy"), progression),
        line(L("settings_exit"), exit),
    ]
    if full {
        let yes = L("season_yes")
        let no = L("season_no")
        lines.append(line(L("settings_miser_exit"), rules.miserRaspExit ? yes : no))
        lines.append(line(
            L("season_consolation"),
            L(rules.consolation == .Zlob ? "settings_consolation_zlob" : "settings_consolation_gentlemen")
        ))
        lines.append(line(L("settings_prikup_consolation"), rules.prikupConsolation ? yes : no))
    }
    return lines
}
