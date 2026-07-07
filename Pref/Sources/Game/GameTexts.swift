import Foundation
import PrefEngine

/// Localized text builders for the game table (ports of Bid.Title, PlayerInfo, GameLog.GetResult).
enum GameTexts {

    static func trumpName(_ trump: Int) -> String {
        switch trump {
        case 0: return L("trump_spades")
        case 1: return L("trump_clubs")
        case 2: return L("trump_diamonds")
        case 3: return L("trump_hearts")
        default: return L("trump_nt")
        }
    }

    static func bidTitle(_ bid: Game.Bid) -> String {
        if bid.pas {
            return L("bid_pas")
        }
        if bid.miser {
            return L("bid_miser")
        }
        return "\(bid.contract) \(trumpName(bid.trump))"
    }

    /// Port of GameMain.PlayerInfo; ">" marks the player whose turn it is.
    static func playerInfo(_ info: TableInfo, _ player: Int) -> String {
        var res = ""
        if player == info.playerInTurn &&
            info.phase != .NotStarted && info.phase != .Ended {
            res += ">"
        }
        res += info.names[player]
        if info.currentGameType == .Normal || info.currentGameType == .Miser {
            if info.phase == .EndTurn || info.phase == .Playing || info.phase == .OpeningChoose {
                if info.contractor == player {
                    res += L("game_role_contract")
                } else if info.isVister[player] == true {
                    res += L("game_role_whist")
                }
            }
        }
        return res
    }

    private static func getMiser(_ game: Calculation.GameResult, _ names: [String]) -> String {
        var res: String
        if game.isSuccessful {
            res = "   " + LF("result_miser_ok", names[game.contractor])
        } else {
            res = "   " + LF("result_miser_fail", names[game.contractor], game.taken[game.contractor] ?? 0)
        }
        if game.halfWithDealer {
            res += LF("result_half_dealer", names[game.dealer])
        }
        res += "."
        return res
    }

    private static func getRaspasy(_ game: Calculation.GameResult, _ names: [String]) -> String {
        var res = "   " + LF("result_raspasy", game.multiplier)
        var first = true
        for p in game.taken.keys {
            if !first {
                res += ","
            }
            first = false
            res += " " + LF("result_raspasy_taken", names[p], game.taken[p] ?? 0)
        }
        res += "."
        return res
    }

    private static func getNormal(_ game: Calculation.GameResult, _ names: [String]) -> String {
        var res: String
        if game.isSuccessful {
            res = "   " + LF("result_normal_ok", names[game.contractor], game.contract)
        } else {
            res = "   " + LF("result_normal_fail", names[game.contractor], game.contract)
        }
        res += LF("result_taken", game.taken[game.contractor] ?? 0)
        switch game.visters.count {
        case 0:
            for pNum in game.taken.keys {
                if pNum != game.contractor && (game.taken[pNum] ?? 0) > 0 {
                    res += LF("result_halfvist", game.taken[pNum] ?? 0, names[pNum])
                }
            }
        case 1:
            res += LF("result_vister", names[game.visters[0]])
        case 2:
            let v1 = game.visters[0]
            let v2 = game.visters[1]
            res += LF("result_visters", names[v1], names[v2])
            res += LF("result_visters_taken", game.taken[v1] ?? 0, game.taken[v2] ?? 0)
        default:
            break
        }
        res += "."
        return res
    }

    private static func getCustom(_ game: Calculation.GameResult, _ names: [String]) -> String {
        guard let score = game.customScore else { return "" }
        var res = "   " + LF("result_custom", names[score.playerNum], score.value)
        switch score.scoreType {
        case .Gora: res += L("result_to_gora")
        case .Pulya: res += L("result_to_pulya")
        case .Visty: res += LF("result_to_visty", names[score.refPlayerNum])
        }
        res += "."
        return res
    }

    /// Port of GameLog.GetResult.
    static func resultText(_ game: Calculation.GameResult, _ names: [String]) -> String {
        switch game.gameType {
        case .Miser: return getMiser(game, names)
        case .Raspasy: return getRaspasy(game, names)
        case .Normal: return getNormal(game, names)
        case .Custom: return getCustom(game, names)
        }
    }

    static func resultText(_ game: Calculation.GameResult, _ calc: Calculation) -> String {
        resultText(game, calc.scores.map { $0.name })
    }

    /// Maps the model's say-animation literals to localized strings.
    static func sayText(_ say: SayEvent) -> String {
        if let bid = say.bid {
            return bidTitle(bid)
        }
        switch say.text {
        case "Вист!": return L("game_say_whist")
        case "Пас": return L("game_say_pass")
        case "В открытую!": return L("game_say_open")
        case "В закрытую": return L("game_say_closed")
        default: return say.text ?? ""
        }
    }
}
