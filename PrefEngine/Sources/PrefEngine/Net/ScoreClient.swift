import Foundation
import CryptoKit

/// Client for the global leaderboard (ScoreServer on the VPS). Reads need the
/// API key; writes are HMAC-signed. Matches Android net/ScoreClient.kt.
///
/// The key and secret ship inside the app binary by design (same as Android),
/// but they are NOT in this public repository: the app injects them at launch
/// from build settings (Config/Secrets.xcconfig, git-ignored) via `configure`.
/// Without them every call degrades gracefully: reads return nil, writes stay
/// queued.
public enum ScoreClient {

    private static let base = "https://scores.preferansmaster.com"
    private static let game = "pref"
    /// The all-time board used by the single-player table.
    public static let allTimeBoard = "alltime"

    private static var credentials: (apiKey: String, secret: String)?

    /// Hands the app's credentials to the client. Empty values count as missing.
    public static func configure(apiKey: String?, secret: String?) {
        if let apiKey = apiKey, let secret = secret, !apiKey.isEmpty, !secret.isEmpty {
            credentials = (apiKey, secret)
        } else {
            credentials = nil
        }
    }

    public static var isConfigured: Bool {
        credentials != nil
    }

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

    /// The season the server is running (its seed derives every deal and rule).
    public struct SeasonInfo {
        public var seasonId: String
        public var startsAt: Int64
        public var endsAt: Int64
        public var seed: String
    }

    private struct SeasonResponse: Codable {
        var season_id: String
        var starts_at: Int64
        var ends_at: Int64
        /// a JSON document stored as text: {"seed":"<hex>"}
        var payload: String?
    }

    private struct SeasonPayload: Codable {
        var seed: String = ""

        private enum CodingKeys: String, CodingKey {
            case seed
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            seed = try c.decodeIfPresent(String.self, forKey: .seed) ?? ""
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

    /// The current season, or nil when none is running, the server is
    /// unreachable or the credentials are missing.
    public static func fetchSeason() async -> SeasonInfo? {
        guard let creds = credentials else { return nil }
        do {
            var req = URLRequest(url: URL(string: "\(base)/v1/\(game)/season/current")!)
            req.setValue(creds.apiKey, forHTTPHeaderField: "X-Api-Key")
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let r = try JSONDecoder().decode(SeasonResponse.self, from: data)
            guard let payload = r.payload,
                  let seed = try? JSONDecoder().decode(SeasonPayload.self, from: Data(payload.utf8)).seed,
                  !seed.isEmpty else {
                return nil
            }
            return SeasonInfo(seasonId: r.season_id, startsAt: r.starts_at, endsAt: r.ends_at, seed: seed)
        } catch {
            NSLog("PrefNet: season fetch failed: %@", "\(error)")
            return nil
        }
    }

    /// A board's top list ("alltime" or "total:<seasonId>"), or nil when the
    /// server is unreachable or the credentials are missing.
    public static func fetchTop(limit: Int = 10, board: String = allTimeBoard) async -> [Entry]? {
        guard let creds = credentials else { return nil }
        do {
            var req = URLRequest(url: URL(string: "\(base)/v1/\(game)/boards/\(board)/top?limit=\(limit)")!)
            req.setValue(creds.apiKey, forHTTPHeaderField: "X-Api-Key")
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
    /// server calls permanent (out of range) is `.drop`; rate limiting, missing
    /// credentials and network failures are `.retry`.
    public static func submit(
        playerId: String,
        name: String,
        score10: Int64,
        deviceTs: Int64,
        board: String = allTimeBoard
    ) async -> SubmitOutcome {
        guard let creds = credentials else { return .retry }
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
            req.setValue(creds.apiKey, forHTTPHeaderField: "X-Api-Key")
            req.setValue(ts, forHTTPHeaderField: "X-Ts")
            req.setValue(sign(creds.secret, signaturePayload(ts, "POST", path, body)), forHTTPHeaderField: "X-Sig")
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
