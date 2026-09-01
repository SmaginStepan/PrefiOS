import Foundation

/// The global leaderboard, offline-friendly: finished-game scores queue in a
/// local file and flush whenever the network allows; the last fetched board is
/// cached for offline viewing, with the classic seeded names as the fallback
/// before the first successful fetch. Matches Android model/GlobalScores.kt.
public enum GlobalScores {

    public struct Row: Codable {
        public var playerId: String
        public var name: String
        /// score in tenths of a whist (server stores integers)
        public var score10: Int64

        public var score: Double {
            Double(score10) / 10.0
        }

        public init(playerId: String, name: String, score10: Int64) {
            self.playerId = playerId
            self.name = name
            self.score10 = score10
        }
    }

    private struct Cache: Codable {
        var rows: [Row] = []
    }

    private struct PendingScore: Codable {
        var name: String
        var score10: Int64
        var deviceTs: Int64
    }

    private struct PendingList: Codable {
        var items: [PendingScore] = []
    }

    private static let cacheFile = "global_scores.json"
    private static let pendingFile = "pending_scores.json"

    /// Only wins of at least this many whists reach the global board.
    public static let minScore = 10.0

    /// The classic table, shown until the first real fetch succeeds.
    public static func seededFallback() -> [Row] {
        [
            Row(playerId: "seed", name: "Эйнштейн", score10: 10000),
            Row(playerId: "seed", name: "Да Винчи", score10: 7500),
            Row(playerId: "seed", name: "Перельман", score10: 5000),
            Row(playerId: "seed", name: "Вован", score10: 3000),
            Row(playerId: "seed", name: "Настасья", score10: 2500),
            Row(playerId: "seed", name: "Алексей", score10: 2000),
            Row(playerId: "seed", name: "Андрей", score10: 1500),
            Row(playerId: "seed", name: "Григорий", score10: 1000),
            Row(playerId: "seed", name: "Ирина", score10: 500),
            Row(playerId: "seed", name: "Степан", score10: 0),
        ]
    }

    public static func cached() -> [Row] {
        guard let text = PrefStorage.readText(cacheFile),
              let cache = try? PrefStorage.decodeFromString(Cache.self, text),
              !cache.rows.isEmpty else {
            return seededFallback()
        }
        return cache.rows
    }

    private static func saveCache(_ rows: [Row]) {
        PrefStorage.writeText(cacheFile, PrefStorage.encodeToString(Cache(rows: rows)))
    }

    private static func loadPending() -> PendingList {
        guard let text = PrefStorage.readText(pendingFile),
              let list = try? PrefStorage.decodeFromString(PendingList.self, text) else {
            return PendingList()
        }
        return list
    }

    private static func savePending(_ p: PendingList) {
        PrefStorage.writeText(pendingFile, PrefStorage.encodeToString(p))
    }

    /// Queues a finished game's result; wins under `minScore` never board.
    public static func enqueue(name: String, score: Double) {
        if score < minScore { return }
        let score10 = Int64((score * 10).rounded())
        var p = loadPending()
        p.items.append(PendingScore(name: name, score10: score10, deviceTs: Int64(Date().timeIntervalSince1970)))
        savePending(p)
    }

    /// Sends every queued score; keeps the ones worth retrying.
    public static func flushPending() async {
        let p = loadPending()
        if p.items.isEmpty { return }
        let playerId = AppSettings().playerId
        var remaining: [PendingScore] = []
        for item in p.items {
            switch await ScoreClient.submit(playerId: playerId, name: item.name, score10: item.score10, deviceTs: item.deviceTs) {
            case .accepted, .drop:
                break
            case .retry:
                remaining.append(item)
            }
        }
        savePending(PendingList(items: remaining))
    }

    /// Flushes the queue, then fetches the fresh top list and caches it.
    /// Returns nil when the server is unreachable (show `cached()`).
    public static func sync() async -> [Row]? {
        await flushPending()
        guard let top = await ScoreClient.fetchTop(limit: 10) else { return nil }
        let rows = top.map { Row(playerId: $0.player_id, name: $0.name, score10: $0.score) }
        saveCache(rows)
        return rows
    }
}
