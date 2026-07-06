import Foundation

/// Any-JSON value: the Swift counterpart of kotlinx's JsonElement for the
/// lobby protocol's opaque `rules` and relayed `data` payloads.
public indirect enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int64.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    // MARK: - Bridging Codable values through JSONValue

    /// Encode any Encodable as a JSONValue (kotlinx encodeToJsonElement).
    public static func from<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try WireJSON.encoder.encode(value)
        return try WireJSON.decoder.decode(JSONValue.self, from: data)
    }

    /// Decode a JSONValue into any Decodable (kotlinx decodeFromJsonElement).
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try WireJSON.encoder.encode(self)
        return try WireJSON.decoder.decode(type, from: data)
    }
}

/// Shared encoder/decoder for everything that goes over the wire.
/// JSONEncoder omits nil optionals (zod's .optional() rejects explicit null)
/// and JSONDecoder ignores unknown keys — the two protocol invariants.
public enum WireJSON {
    public static let encoder = JSONEncoder()
    public static let decoder = JSONDecoder()

    public static func encodeToString<T: Encodable>(_ value: T) throws -> String {
        String(data: try encoder.encode(value), encoding: .utf8) ?? ""
    }

    public static func decodeFromString<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
        try decoder.decode(type, from: Data(text.utf8))
    }
}
