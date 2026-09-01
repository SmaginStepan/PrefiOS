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
        get { data.limit < 1 ? 40 : AppSettings.clampLimit(data.limit) }
        set {
            data.limit = AppSettings.clampLimit(newValue)
            save()
        }
    }

    // Pool limit bounds for new games and sheets (existing saved pulkas
    // keep whatever limit they were created with).
    public static let minLimit = 10
    public static let maxLimit = 100

    public static func clampLimit(_ value: Int) -> Int {
        min(max(value, minLimit), maxLimit)
    }

    /// Persisted device UUID: the multiplayer identity and reconnect token.
    public var playerId: String {
        if data.playerId.isEmpty {
            data.playerId = UUID().uuidString.lowercased() // Android emits lowercase UUIDs
            save()
        }
        return data.playerId
    }

    /// True while the user never typed their own name.
    public var isDefaultPlayerName: Bool {
        AppSettings.isDefaultName(data.playerName)
    }

    // Per-locale placeholder names; treated as "not customized" so the
    // display can follow the app language (QA M-01).
    private static let defaultNames: Set<String> = ["", "Игрок", "Player", "Jugador"]

    public static func isDefaultName(_ name: String) -> Bool {
        defaultNames.contains(name.trimmingCharacters(in: .whitespaces))
    }

    private static let fileName = "settings.json"
}
