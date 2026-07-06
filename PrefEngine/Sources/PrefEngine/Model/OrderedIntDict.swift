import Foundation

/// Insertion-ordered Int-keyed dictionary mirroring Kotlin's LinkedHashMap.
/// The engine relies on insertion order in several places (`isVister.values.first()`,
/// two-vister order in `getGameResult`, `inPlay` iteration), so a plain Swift
/// Dictionary cannot be used. Encodes as a JSON object with stringified keys
/// (like kotlinx.serialization); on decode, keys are sorted numerically.
public struct OrderedIntDict<Value> {
    public private(set) var keys: [Int] = []
    private var storage: [Int: Value] = [:]

    public init() {}

    public var isEmpty: Bool { keys.isEmpty }
    public var count: Int { keys.count }

    public var values: [Value] { keys.map { storage[$0]! } }

    public subscript(key: Int) -> Value? {
        get { storage[key] }
        set {
            if let newValue = newValue {
                if storage[key] == nil {
                    keys.append(key)
                }
                storage[key] = newValue
            } else {
                if storage[key] != nil {
                    keys.removeAll { $0 == key }
                    storage[key] = nil
                }
            }
        }
    }

    public func containsKey(_ key: Int) -> Bool {
        storage[key] != nil
    }

    public mutating func removeAll() {
        keys.removeAll()
        storage.removeAll()
    }

    /// Insertion-ordered (key, value) pairs.
    public var entries: [(key: Int, value: Value)] {
        keys.map { ($0, storage[$0]!) }
    }
}

extension OrderedIntDict: Codable where Value: Codable {
    private struct StringKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = Int(stringValue)
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: StringKey.self)
        let sortedKeys = container.allKeys.compactMap { key -> (Int, StringKey)? in
            guard let intKey = Int(key.stringValue) else { return nil }
            return (intKey, key)
        }.sorted { $0.0 < $1.0 }
        for (intKey, codingKey) in sortedKeys {
            self[intKey] = try container.decode(Value.self, forKey: codingKey)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringKey.self)
        for key in keys {
            try container.encode(storage[key]!, forKey: StringKey(intValue: key)!)
        }
    }
}
