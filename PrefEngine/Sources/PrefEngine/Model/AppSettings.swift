import Foundation

/// Replacement for WP7 IsolatedStorageSettings: a small JSON file in app storage.
public final class AppSettings {

    private final class Data_: Codable {
        var rules: GameRules = GameRules()
        var playerName: String = "Игрок"
        var limit: Int = 40
        var playerId: String = ""

        private enum CodingKeys: String, CodingKey {
            case rules, playerName, limit, playerId
        }

        init() {}

        required init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            rules = try c.decodeIfPresent(GameRules.self, forKey: .rules) ?? GameRules()
            playerName = try c.decodeIfPresent(String.self, forKey: .playerName) ?? "Игрок"
            limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? 40
            playerId = try c.decodeIfPresent(String.self, forKey: .playerId) ?? ""
        }
    }

    private var data: Data_

    public init() {
        data = AppSettings.load()
    }

    private static func load() -> Data_ {
        guard let text = PrefStorage.readText(fileName),
              let data = try? PrefStorage.decodeFromString(Data_.self, text) else {
            return Data_()
        }
        return data
    }

    private func save() {
        PrefStorage.writeText(AppSettings.fileName, PrefStorage.encodeToString(data))
    }

    public var rules: GameRules {
        get { data.rules }
        set {
            data.rules = newValue
            save()
        }
    }

    public var playerName: String {
        get { data.playerName }
        set {
            data.playerName = newValue
            save()
        }
    }

    public var limit: Int {
        get { data.limit < 1 ? 40 : data.limit }
        set {
            if newValue < 1 {
                return
            }
            data.limit = newValue
            save()
        }
    }

    /// Persisted device UUID: the multiplayer identity and reconnect token.
    public var playerId: String {
        if data.playerId.isEmpty {
            data.playerId = UUID().uuidString.lowercased() // Android emits lowercase UUIDs
            save()
        }
        return data.playerId
    }

    private static let fileName = "settings.json"
}
