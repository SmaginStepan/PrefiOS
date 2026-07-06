import Foundation

/// Replacement for WP7 IsolatedStorage: plain files in the app's private files dir.
/// Must be initialized once with `initialize` before any model class is used.
public enum PrefStorage {
    public private(set) static var dir: URL!

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public static let decoder = JSONDecoder()

    public static func initialize(filesDir: URL) {
        dir = filesDir
    }

    public static func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path)
    }

    public static func readText(_ name: String) -> String? {
        let url = dir.appendingPathComponent(name)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    public static func writeText(_ name: String, _ text: String) {
        let url = dir.appendingPathComponent(name)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
    }

    public static func listFiles(prefix: String) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.filter { $0.hasPrefix(prefix) }
    }

    /// Original Save() deleted all files sharing the name's prefix up to the last '_'.
    public static func deleteFamily(_ name: String) {
        if let index = name.lastIndex(of: "_"), index != name.startIndex {
            let prefix = String(name[name.startIndex..<index])
            for file in listFiles(prefix: prefix) {
                delete(file)
            }
        }
    }

    public static func encodeToString<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    public static func decodeFromString<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
        try decoder.decode(type, from: Data(text.utf8))
    }
}
