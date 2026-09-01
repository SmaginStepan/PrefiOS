import Foundation
import CryptoKit

/// Client for the global leaderboard (ScoreServer on the VPS). Reads need the
/// API key; writes are HMAC-signed. Matches Android net/ScoreClient.kt.
public enum ScoreClient {

    private static let base = "https://scores.preferansmaster.com"
    private static let game = "pref"
    private static let board = "alltime"
    // Shipping in the binary by design (same as Android).
    private static let apiKey = "1711193a9bc38cf8ec25876c09981f7d"
    private static let secret = "9bc01938a5d526e89f1cc67abed8e599924537d84d0217e0e3f67439a1dd27d6"

    public struct Entry: Codable {
        public var rank: Int
        public var player_id: String
        public var name: String
        public var score: Int64

        private enum CodingKeys: String, CodingKey {
            case rank, player_id, name, score
        }

        public init(rank: Int, player_id: String, name: String, score: Int64) {
            self.rank = rank
            self.player_id = player_id
            self.name = name
            self.score = score
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 0
            player_id = try c.decodeIfPresent(String.self, forKey: .player_id) ?? ""
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            score = try c.decodeIfPresent(Int64.self, forKey: .score) ?? 0
        }
    }

    private struct TopResponse: Codable {
        var entries: [Entry] = []

        private enum CodingKeys: String, CodingKey {
            case entries
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            entries = try c.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        }
    }

    private struct SubmitBody: Codable {
        let player_id: String
        let name: String
        let score: Int64
        let device_ts: Int64
    }

    private struct SubmitResponse: Codable {
        var accepted = false
        var reason: String?

        private enum CodingKeys: String, CodingKey {
            case accepted, reason
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            accepted = try c.decodeIfPresent(Bool.self, forKey: .accepted) ?? false
            reason = try c.decodeIfPresent(String.self, forKey: .reason)
        }
    }

    /// What to do with a queued submission after one attempt.
    public enum SubmitOutcome {
        case accepted, drop, retry
    }

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 10
        return URLSession(configuration: cfg)
    }()

    /// The global top list, or nil when the server is unreachable.
    public static func fetchTop(limit: Int = 10) async -> [Entry]? {
        do {
            var req = URLRequest(url: URL(string: "\(base)/v1/\(game)/boards/\(board)/top?limit=\(limit)")!)
            req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(TopResponse.self, from: data).entries
        } catch {
            NSLog("PrefNet: score top failed: %@", "\(error)")
            return nil
        }
    }

    /// Submits one score (already in the x10 integer scale). A rejection the
    /// server calls permanent (out of range) is `.drop`; rate limiting and
    /// network failures are `.retry`.
    public static func submit(playerId: String, name: String, score10: Int64, deviceTs: Int64) async -> SubmitOutcome {
        do {
            let path = "/v1/\(game)/boards/\(board)/scores"
            let body = try JSONEncoder().encode(
                SubmitBody(player_id: playerId, name: name, score: score10, device_ts: deviceTs)
            )
            // unix seconds, UTC — a local-time timestamp is rejected as
            // "timestamp outside window"
            let ts = String(Int64(Date().timeIntervalSince1970))
            var req = URLRequest(url: URL(string: "\(base)\(path)")!)
            req.httpMethod = "POST"
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
            req.setValue(ts, forHTTPHeaderField: "X-Ts")
            req.setValue(sign(secret, signaturePayload(ts, "POST", path, body)), forHTTPHeaderField: "X-Sig")
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .retry // 5xx, 401 clock drift…
            }
            let r = try JSONDecoder().decode(SubmitResponse.self, from: data)
            if r.accepted {
                return .accepted
            }
            return r.reason == "submitting too fast" ? .retry : .drop // out of range / above maximum
        } catch {
            NSLog("PrefNet: score submit failed: %@", "\(error)")
            return .retry
        }
    }

    // sig = HMAC-SHA256(secret, "{ts}\n{METHOD}\n{path}\n{sha256hex(body)}"), lowercase hex
    static func signaturePayload(_ ts: String, _ method: String, _ path: String, _ body: Data) -> String {
        let bodyHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        return "\(ts)\n\(method.uppercased())\n\(path)\n\(bodyHash)"
    }

    static func sign(_ secret: String, _ payload: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }
}
