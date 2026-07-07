import Foundation

public enum ScoreValueType: String, Codable { case Gora, Pulya, Visty }
public enum GameType: String, Codable { case Raspasy, Miser, Normal, Custom }

public final class Calculation: Codable {

    public final class Player: Codable {
        public var name: String = ""
        public var gora: Int = 0
        public var pulya: Int = 0
        public var visty: OrderedIntDict<Int> = OrderedIntDict()
        public var score: Double = 0.0

        public init() {}
    }

    public final class ScoreEntry: Codable {
        public var scoreType: ScoreValueType = .Gora
        public var playerNum: Int = 0
        public var refPlayerNum: Int = 0
        public var value: Int = 0

        public init() {}
    }

    public final class GameResult: Codable {
        public var gameType: GameType = .Raspasy
        public var dealer: Int = 0
        public var contractor: Int = 0
        public var contract: Int = 0
        public var taken: OrderedIntDict<Int> = OrderedIntDict()
        public var visters: [Int] = []
        public var multiplier: Int = 1
        public var halfWithDealer: Bool = false
        public var customScore: ScoreEntry?

        public init() {}

        public var isSuccessful: Bool {
            if gameType == .Normal {
                return (taken[contractor] ?? 0) >= contract
            }
            if gameType == .Miser {
                return (taken[contractor] ?? 0) == 0
            }
            return false
        }

        public var sumVistNeeded: Int {
            switch contract {
            case 6: return 4
            case 7: return 2
            case 8: return 1
            case 9: return 1
            default: return 0
            }
        }

        public var singleVistNeeded: Int {
            switch contract {
            case 6: return 2
            case 7: return 1
            case 8: return 1
            case 9: return 1
            default: return 0
            }
        }
    }

    public var limit: Int = 40
    public var scores: [Player] = []
    public var created: Int64 = 0
    public var gameLog: [GameResult] = []
    public var log: [ScoreEntry] = []
    public var dealer: Int = 0
    public var rules: GameRules = GameRules()

    public init() {}

    public convenience init(playersCount: Int, limit: Int = 40) {
        self.init()
        self.limit = limit
        created = Int64(Date().timeIntervalSince1970 * 1000)
        rules = AppSettings().rules.clone()
        dealer = Int.random(in: 0..<playersCount)
        for i in 0..<playersCount {
            let player = Player()
            player.name = "Игрок " + String(i + 1)
            scores.append(player)
        }
        for i in 0..<playersCount {
            for j in 0..<playersCount where i != j {
                scores[i].visty[j] = 0
            }
        }
    }

    public var playersCount: Int {
        scores.count
    }

    // MARK: - Current raspasy progression

    public var raspasyLength: Int {
        var len = 0
        var raspasyFound = false
        for i in gameLog.indices.reversed() {
            let game = gameLog[i]
            if game.gameType == .Raspasy {
                raspasyFound = true
            }
            if game.isSuccessful || (rules.miserRaspExit && game.gameType == .Miser) {
                break
            }
            if game.gameType == .Raspasy {
                len += 1
            }
        }
        return raspasyFound ? len : 0
    }

    public var currentRaspasyMultiplier: Int {
        let length = raspasyLength
        let progress: [Int]
        switch rules.raspasyProgression {
        case .NoProgression1: return 1
        case .Arifm1233: progress = [1, 2, 3, 3]
        case .Geom1244: progress = [1, 2, 4, 4]
        }
        if length >= 3 {
            return progress[3]
        }
        return progress[length]
    }

    public var currentRaspasyExit: Int {
        let length = raspasyLength
        let progress: [Int]
        switch rules.raspasyExit {
        case .Easy6: progress = [6, 6, 6]
        case .Med677: progress = [6, 7, 7]
        case .Hard678: progress = [6, 7, 8]
        }
        if length >= 2 {
            return progress[2]
        }
        return progress[length]
    }

    public func writeGame(_ game: GameResult) {
        if game.gameType == .Raspasy {
            // РАСПАСЫ: определяем кто взял меньше всех
            var pMin = -1
            var pMin2 = -1
            var tMin = 100
            var tMin2 = 100
            for pNum in game.taken.keys {
                if game.taken[pNum]! < tMin {
                    // Глобальный минимум для списания
                    tMin = game.taken[pNum]!
                }
                if pNum != game.dealer || playersCount == 3 {
                    // Минимумы по игрокам не сидящим на прикупе
                    if game.taken[pNum]! < tMin2 {
                        pMin = pNum
                        pMin2 = -1
                        tMin2 = game.taken[pNum]!
                    } else if game.taken[pNum]! == tMin2 {
                        pMin2 = pNum
                    }
                }
            }

            if rules.gameType != .Rostov {
                // Пишем в горку
                for pNum in game.taken.keys {
                    let toAdd = game.multiplier * (game.taken[pNum]! - tMin)
                    if toAdd > 0 {
                        addValue(.Gora, toAdd, pNum)
                    }
                }
            } else {
                // Пишем висты
                if pMin2 < 0 {
                    // Один взял меньше всех
                    for pNum in game.taken.keys {
                        if pNum != pMin && (pNum != game.dealer || playersCount == 3) {
                            let v = rules.vistTakeOnRaspas * (game.taken[pNum]! - tMin2)
                            if pMin2 < 0 {
                                addValue(.Visty, v, pMin, pNum)
                            } else {
                                addValue(.Visty, v / 2, pMin, pNum)
                                addValue(.Visty, v / 2, pMin2, pNum)
                            }
                        }
                    }
                }

                // Пишем в пулю сдающему за невзятие
                if game.taken[game.dealer] == 0 {
                    addValue(.Pulya, game.multiplier, game.dealer)
                }
            }

            // Пишем в пулю за невзятие
            if tMin2 == 0 {
                addValue(.Pulya, game.multiplier, pMin)
                if pMin2 >= 0 {
                    addValue(.Pulya, game.multiplier, pMin2)
                }
            }
        } else if game.gameType == .Miser {
            // МИЗЕР
            if game.isSuccessful {
                if game.halfWithDealer {
                    addValue(.Pulya, 5, game.contractor)
                    addValue(.Pulya, 5, game.dealer)
                } else {
                    addValue(.Pulya, 10, game.contractor)
                }
            } else {
                if game.halfWithDealer {
                    addValue(.Gora, 5 * game.taken[game.contractor]!, game.contractor)
                    addValue(.Gora, 5 * game.taken[game.contractor]!, game.dealer)
                } else {
                    addValue(.Gora, 10 * game.taken[game.contractor]!, game.contractor)
                }
            }
        } else if game.gameType == .Normal {
            // ИГРА
            let gameValue = (game.contract - 5) * 2
            var mulct = gameValue
            if rules.vist == .HalfResponsibility {
                mulct /= 2
            }
            let vistSum = 10 - game.taken[game.contractor]!

            if game.isSuccessful {
                addValue(.Pulya, gameValue, game.contractor)

                if game.visters.isEmpty {
                    // Никто не вистовал
                    if game.contract < 8 && game.taken[game.contractor] == game.contract {
                        // Пишем полвиста
                        for pNum in game.taken.keys {
                            if pNum != game.contractor {
                                if (game.contract == 6 && game.taken[pNum] == 2) || (game.contract == 7 && game.taken[pNum] == 1) {
                                    addValue(.Visty, 4, pNum, game.contractor)
                                }
                            }
                        }
                    }
                } else if game.visters.count == 1 {
                    // Один вистующий
                    addValue(.Visty, gameValue * vistSum, game.visters[0], game.contractor)

                    if vistSum < game.sumVistNeeded {
                        // Пишем гору вистующему
                        addValue(.Gora, mulct * (game.sumVistNeeded - vistSum), game.visters[0])
                    }
                } else if game.visters.count == 2 {
                    // Два виста
                    addValue(.Visty, game.taken[game.visters[0]]! * gameValue, game.visters[0], game.contractor)
                    addValue(.Visty, game.taken[game.visters[1]]! * gameValue, game.visters[1], game.contractor)

                    if vistSum < game.sumVistNeeded {
                        // Пишем гору вистующим
                        for vister in game.visters {
                            let taken = game.taken[vister]!
                            if taken < game.singleVistNeeded {
                                addValue(.Gora, mulct * (game.singleVistNeeded - taken), vister)
                            }
                        }
                    }
                }
            } else {
                let left = game.contract - game.taken[game.contractor]!
                addValue(.Gora, (game.contract - 5) * 2 * left, game.contractor)

                // Консоляция и висты вистующим
                var consolation = gameValue
                if rules.consolationBonus == .Max10 {
                    consolation = 10
                }

                if game.visters.count == 1 {
                    // Один вистующий: определяем пасующего
                    var passer = -1
                    for pNum in 0..<playersCount {
                        if (playersCount == 3 || (game.visters[0] != game.dealer && pNum != dealer)) && pNum != game.visters[0] && pNum != game.contractor {
                            passer = pNum
                        }
                    }

                    if passer < 0 {
                        // пасующего нет - вистует "прикупщик" - он пишет все висты на себя
                        addValue(.Visty, vistSum * gameValue + left * consolation, game.visters[0], game.contractor)
                        // Пишем консоляцию оставшимся
                        for pNum in 0..<playersCount {
                            if pNum != game.contractor && pNum != game.visters[0] {
                                if rules.prikupConsolation {
                                    addValue(.Visty, left * consolation, pNum, game.contractor)
                                } else {
                                    // Если по правилам консоляция прикупщику не положена, то делим остаток пополам
                                    addValue(.Visty, left * consolation / 2, pNum, game.contractor)
                                }
                            }
                        }
                    } else {
                        if rules.consolation == .Gentlemen {
                            // Джентельменский вист
                            addValue(.Visty, vistSum * gameValue / 2 + left * consolation, game.visters[0], game.contractor)
                            addValue(.Visty, vistSum * gameValue / 2 + left * consolation, passer, game.contractor)
                        } else {
                            // Жлобский вист
                            addValue(.Visty, vistSum * gameValue + left * consolation, game.visters[0], game.contractor)
                            addValue(.Visty, left * consolation, passer, game.contractor)
                        }

                        if rules.prikupConsolation && playersCount == 4 {
                            // Пишем консоляцию "прикупщику"
                            addValue(.Visty, left * consolation, game.dealer, game.contractor)
                        }
                    }
                } else if game.visters.count == 2 {
                    // Два виста
                    addValue(.Visty, game.taken[game.visters[0]]! * gameValue + left * consolation, game.visters[0], game.contractor)
                    addValue(.Visty, game.taken[game.visters[1]]! * gameValue + left * consolation, game.visters[1], game.contractor)

                    if rules.prikupConsolation && playersCount == 4 {
                        // Пишем консоляцию "прикупщику"
                        addValue(.Visty, left * consolation, game.dealer, game.contractor)
                    }
                }
            }
        }

        gameLog.append(game)
        if game.isSuccessful || raspasyLength == 0 || game.gameType == .Raspasy {
            dealer += 1
        }
        if dealer >= playersCount {
            dealer = 0
        }
    }

    public var isFinished: Bool {
        var finished = true
        var sum = 0
        for score in scores {
            if rules.ending == .Each {
                finished = finished && score.pulya == limit
            }
            sum += score.pulya
        }
        if rules.ending == .Sum {
            return sum >= limit
        }
        return finished
    }

    public func addValue(_ scoreType: ScoreValueType, _ value: Int, _ playerNum: Int, _ refPlayerNum: Int = 0) {
        var value = value
        var pulyaToGora = 1
        if rules.scoring == .Leningrad {
            pulyaToGora = 2
        }

        if scoreType == .Gora {
            value = scores[playerNum].gora + pulyaToGora * value
            scores[playerNum].gora = value
        } else if scoreType == .Pulya {
            value += scores[playerNum].pulya

            // Проверяем закрытие
            if rules.ending == .Each && value > limit {
                var overdraft = value - limit
                value = limit
                while overdraft > 0 {
                    var extrem = Int.min
                    var donor = -1
                    var pNum = playerNum
                    for _ in 0..<playersCount {
                        pNum += 1
                        if pNum >= playersCount {
                            pNum = 0
                        }
                        if pNum != playerNum && (playersCount == 3 || pNum != dealer) && scores[pNum].pulya < limit {
                            let v = scores[pNum].pulya
                            if v > extrem {
                                extrem = v
                                donor = pNum
                            }
                        }
                    }

                    if donor >= 0 {
                        var toWrite = scores[donor].pulya + overdraft
                        var part = overdraft
                        overdraft = 0
                        if toWrite > limit {
                            overdraft = toWrite - limit
                            part -= overdraft
                            toWrite = limit
                        }
                        setValue(.Pulya, toWrite, donor, 0, custom: false)
                        addValue(.Visty, part * 10, playerNum, donor)
                    } else {
                        addValue(.Gora, -overdraft, playerNum)
                        overdraft = 0
                    }
                }
            }

            scores[playerNum].pulya = value
        } else if scoreType == .Visty {
            value = scores[playerNum].visty[refPlayerNum]! + pulyaToGora * value
            scores[playerNum].visty[refPlayerNum] = value
        }

        let entry = ScoreEntry()
        entry.scoreType = scoreType
        entry.playerNum = playerNum
        entry.refPlayerNum = refPlayerNum
        entry.value = value
        log.append(entry)
    }

    public func setValue(_ scoreType: ScoreValueType, _ value: Int, _ playerNum: Int, _ refPlayerNum: Int = 0, custom: Bool = true) {
        var diff = 0
        if scoreType == .Gora {
            diff = value - scores[playerNum].gora
            scores[playerNum].gora = value
        } else if scoreType == .Pulya {
            diff = value - scores[playerNum].pulya
            scores[playerNum].pulya = value
        } else if scoreType == .Visty {
            diff = value - scores[playerNum].visty[refPlayerNum]!
            scores[playerNum].visty[refPlayerNum] = value
        }
        if custom {
            let result = GameResult()
            result.gameType = .Custom
            let e = ScoreEntry()
            e.scoreType = scoreType
            e.playerNum = playerNum
            e.refPlayerNum = refPlayerNum
            e.value = diff
            result.customScore = e
            gameLog.append(result)
        }
        let entry = ScoreEntry()
        entry.scoreType = scoreType
        entry.playerNum = playerNum
        entry.refPlayerNum = refPlayerNum
        entry.value = value
        log.append(entry)
    }

    public func getValueHistory(_ scoreType: ScoreValueType, _ playerNum: Int, _ refPlayerNum: Int = 0) -> String {
        var vals = log.filter { $0.scoreType == scoreType && $0.playerNum == playerNum && $0.refPlayerNum == refPlayerNum }
            .map { $0.value }

        var res = ""
        if vals.count > 10 {
            res = "..."
            vals = Array(vals.dropFirst(vals.count - 10))
        }
        var f = true
        for v in vals {
            if !f {
                res += "."
            }
            f = false
            res += String(v)
        }
        return res
    }

    /// Final settlement: distribute pulya and gora into each player's score.
    public func calc() {
        // Копируем данные
        var tmp: [Player] = []

        var sumPulya = 0
        for sc in scores {
            let pl = Player()
            pl.gora = sc.gora
            pl.pulya = sc.pulya
            sumPulya += pl.pulya
            for p in sc.visty.keys {
                pl.visty[p] = sc.visty[p]!
            }
            tmp.append(pl)
        }

        // Расписываем пулю
        var pulyaToGora = 1
        if rules.scoring == .Leningrad {
            pulyaToGora = 2
        }

        let avgPulya = sumPulya / playersCount
        var sumGora = 0
        for i in 0..<playersCount {
            tmp[i].gora += pulyaToGora * (avgPulya - tmp[i].pulya)
            sumGora += tmp[i].gora
        }

        // Расписываем гору
        let avgGora = (10 * Double(sumGora)) / Double(playersCount)
        for i in 0..<playersCount {
            tmp[i].score = avgGora - Double(tmp[i].gora * 10)
            // Подсчитываем висты
            for j in 0..<playersCount where i != j {
                tmp[i].score += Double(tmp[i].visty[j]! - tmp[j].visty[i]!)
            }
            scores[i].score = tmp[i].score
        }
    }

    /// Copy with the player columns rearranged: new index i takes old column
    /// order[i]. Every player reference (visty keys, game log, score log,
    /// dealer) is remapped, so a saved pulka can seat its players differently
    /// when a multiplayer game resumes from it.
    public func reordered(_ order: [Int]) -> Calculation {
        var inv = [Int](repeating: 0, count: playersCount)
        for i in order.indices {
            inv[order[i]] = i
        }
        func mp(_ p: Int) -> Int {
            (0..<playersCount).contains(p) ? inv[p] : p
        }
        func mpEntry(_ c: ScoreEntry) -> ScoreEntry {
            let it = ScoreEntry()
            it.scoreType = c.scoreType
            it.playerNum = mp(c.playerNum)
            it.refPlayerNum = mp(c.refPlayerNum)
            it.value = c.value
            return it
        }
        let out = Calculation()
        out.limit = limit
        out.created = created
        out.dealer = mp(dealer)
        out.rules = rules.clone()
        out.scores = order.map { old in
            let s = scores[old]
            let n = Player()
            n.name = s.name
            n.gora = s.gora
            n.pulya = s.pulya
            n.score = s.score
            for (k, v) in s.visty.entries {
                n.visty[mp(k)] = v
            }
            return n
        }
        out.gameLog = gameLog.map { g in
            let n = GameResult()
            n.gameType = g.gameType
            n.dealer = mp(g.dealer)
            n.contractor = mp(g.contractor)
            n.contract = g.contract
            for (k, v) in g.taken.entries {
                n.taken[mp(k)] = v
            }
            n.visters = g.visters.map { mp($0) }
            n.multiplier = g.multiplier
            n.halfWithDealer = g.halfWithDealer
            n.customScore = g.customScore.map { mpEntry($0) }
            return n
        }
        out.log = log.map { mpEntry($0) }
        return out
    }

    /// Which pulka column each seat should take: match by name first
    /// (trimmed, case-insensitive), the rest keep their relative order.
    public static func seatOrder(_ seatNames: [String], _ calc: Calculation) -> [Int] {
        let n = calc.playersCount
        var taken = [Bool](repeating: false, count: n)
        var order = [Int](repeating: -1, count: Swift.min(seatNames.count, n))
        for i in order.indices {
            let name = seatNames[i].trimmingCharacters(in: .whitespaces).lowercased()
            if let hit = (0..<n).first(where: {
                !taken[$0] && calc.scores[$0].name.trimmingCharacters(in: .whitespaces).lowercased() == name
            }) {
                order[i] = hit
                taken[hit] = true
            }
        }
        for i in order.indices where order[i] < 0 {
            let free = (0..<n).first { !taken[$0] }!
            order[i] = free
            taken[free] = true
        }
        return order
    }

    public func save() {
        let name = Calculation.getFileName(created: created, playersCount: playersCount, limit: limit)
        save(name)
    }

    public func save(_ name: String) {
        PrefStorage.deleteFamily(name)
        PrefStorage.writeText(name, PrefStorage.encodeToString(self))
    }

    public func saveLast() {
        save("lastcalc.json")
    }

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func fileDate(_ created: Int64) -> String {
        fileDateFormatter.string(from: Date(timeIntervalSince1970: Double(created) / 1000.0))
    }

    public static func getFileName(created: Int64, playersCount: Int, limit: Int) -> String {
        "pulya_\(fileDate(created))_\(playersCount)_\(limit).json"
    }

    public static func parseFileDate(_ s: String) -> Int64 {
        guard let date = fileDateFormatter.date(from: s) else { return 0 }
        return Int64(date.timeIntervalSince1970 * 1000)
    }

    public static func load(created: Int64, playersCount: Int, limit: Int) -> Calculation? {
        let name = getFileName(created: created, playersCount: playersCount, limit: limit)
        return load(name)
    }

    public static func load(_ name: String) -> Calculation? {
        guard let text = PrefStorage.readText(name) else { return nil }
        return try? PrefStorage.decodeFromString(Calculation.self, text)
    }

    public static func loadLast() -> Calculation? {
        load("lastcalc.json")
    }
}
