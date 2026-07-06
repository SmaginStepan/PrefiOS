import Foundation

/// Replacement for WP7 IsolatedStorageSettings: a small JSON file in app storage.
public final class AppSettings {

    private final class Data_: Codable {
        var rules: GameRules = GameRules()
        var playerName: String = "Игрок"
        var limit: Int = 40

        private enum CodingKeys: String, CodingKey {
            case rules, playerName, limit
        }

        init() {}
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

    private static let fileName = "settings.json"
}
