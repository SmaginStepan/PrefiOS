import Foundation

public final class HighScoresTable: Codable {

    public final class PlayerScore: Codable {
        public var playerName: String = ""
        public var score: Double = 0.0
        public var lastAdded: Bool = false

        public init() {}
    }

    public var scores: [PlayerScore] = []

    public init() {}

    public var minScore: Double {
        scores.map { $0.score }.min() ?? 0.0
    }

    @discardableResult
    public func fillDefaults() -> HighScoresTable {
        addScore("Эйнштейн", 1000.0)
        addScore("Да Винчи", 750.0)
        addScore("Перельман", 500.0)
        addScore("Вован", 300.0)
        addScore("Настасья", 250.0)
        addScore("Алексей", 200.0)
        addScore("Андрей", 150.0)
        addScore("Григорий", 100.0)
        addScore("Ирина", 50.0)
        addScore("Степан", 0.0)
        return self
    }

    @discardableResult
    public func addScore(_ playerName: String, _ score: Double) -> Bool {
        if scores.count >= 10 && score < minScore {
            return false
        }
        let ps = PlayerScore()
        ps.playerName = playerName
        ps.score = score
        ps.lastAdded = true
        scores.append(ps)
        scores = Array(scores.sorted { $0.score > $1.score }.prefix(10))
        return true
    }

    public func save() {
        PrefStorage.writeText(HighScoresTable.fileName, PrefStorage.encodeToString(self))
    }

    private static let fileName = "highscores.json"

    public static func load() -> HighScoresTable {
        let res: HighScoresTable
        if !PrefStorage.exists(fileName) {
            res = HighScoresTable().fillDefaults()
        } else {
            let text = PrefStorage.readText(fileName)!
            res = (try? PrefStorage.decodeFromString(HighScoresTable.self, text)) ?? HighScoresTable().fillDefaults()
        }
        for sc in res.scores {
            sc.lastAdded = false
        }
        return res
    }
}
