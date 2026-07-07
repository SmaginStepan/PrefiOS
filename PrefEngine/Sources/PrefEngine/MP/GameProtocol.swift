import Foundation

/// Host <-> guest game messages, carried inside the lobby relay's opaque
/// `data` field. Everything a guest renders arrives pre-rotated (the guest is
/// always seat 0 of its own view) and pre-redacted (hidden hands are null cards).
/// Discriminated by "t": "state" | "act" — matches Android mp/GameProtocol.kt.

/// What input the actor is being asked for.
public struct Ask: Codable {
    public var kind: String // bid | contract | vist | opening | discard | play | confirm
    public var bids: [Game.Bid]?
    public var allowed: [Card]?

    public init(_ kind: String, bids: [Game.Bid]? = nil, allowed: [Card]? = nil) {
        self.kind = kind
        self.bids = bids
        self.allowed = allowed
    }
}

/// Score standing shown between deals (already rotated per viewer).
public struct ScoreSnap: Codable {
    public var names: [String]
    public var pulya: [Int]
    public var gora: [Int]
    /// visty[i][j] = whists player i has written on player j (diagonal 0).
    public var visty: [[Int]]
    public var limit: Int
    /// who deals the next deal (viewer-relative); lets a guest save a resumable pulka
    public var dealer: Int

    public init(names: [String], pulya: [Int], gora: [Int], visty: [[Int]], limit: Int, dealer: Int = 0) {
        self.names = names
        self.pulya = pulya
        self.gora = gora
        self.visty = visty
        self.limit = limit
        self.dealer = dealer
    }

    private enum CodingKeys: String, CodingKey {
        case names, pulya, gora, visty, limit, dealer
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        names = try c.decode([String].self, forKey: .names)
        pulya = try c.decode([Int].self, forKey: .pulya)
        gora = try c.decode([Int].self, forKey: .gora)
        visty = try c.decodeIfPresent([[Int]].self, forKey: .visty) ?? []
        limit = try c.decode(Int.self, forKey: .limit)
        dealer = try c.decodeIfPresent(Int.self, forKey: .dealer) ?? 0
    }
}

public enum GameMsg {
    /// Full render state for one viewer.
    public struct State {
        public var field: [PlacedCard]
        public var info: TableInfo
        public var yourTurn: Bool
        public var ask: Ask?
        public var badMove: Bool
        public var ended: Bool
        public var scores: ScoreSnap?

        public init(
            field: [PlacedCard],
            info: TableInfo,
            yourTurn: Bool,
            ask: Ask? = nil,
            badMove: Bool = false,
            ended: Bool = false,
            scores: ScoreSnap? = nil
        ) {
            self.field = field
            self.info = info
            self.yourTurn = yourTurn
            self.ask = ask
            self.badMove = badMove
            self.ended = ended
            self.scores = scores
        }
    }

    /// A guest's answer to an Ask. Exactly one field is set.
    public struct Act {
        public var bid: Game.Bid?
        public var contract: Game.Bid?
        public var vist: Bool?
        public var opening: Bool?
        public var discard: [Card]?
        public var play: Card?
        public var confirm: Bool?

        public init(
            bid: Game.Bid? = nil,
            contract: Game.Bid? = nil,
            vist: Bool? = nil,
            opening: Bool? = nil,
            discard: [Card]? = nil,
            play: Card? = nil,
            confirm: Bool? = nil
        ) {
            self.bid = bid
            self.contract = contract
            self.vist = vist
            self.opening = opening
            self.discard = discard
            self.play = play
            self.confirm = confirm
        }
    }

    case state(State)
    case act(Act)
}

extension GameMsg: Codable {
    private enum CodingKeys: String, CodingKey {
        case t
        // state
        case field, info, yourTurn, ask, badMove, ended, scores
        // act
        case bid, contract, vist, opening, discard, play, confirm
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decode(String.self, forKey: .t)
        switch t {
        case "state":
            self = .state(State(
                field: try c.decodeIfPresent([PlacedCard].self, forKey: .field) ?? [],
                info: try c.decodeIfPresent(TableInfo.self, forKey: .info) ?? TableInfo(),
                yourTurn: try c.decodeIfPresent(Bool.self, forKey: .yourTurn) ?? false,
                ask: try c.decodeIfPresent(Ask.self, forKey: .ask),
                badMove: try c.decodeIfPresent(Bool.self, forKey: .badMove) ?? false,
                ended: try c.decodeIfPresent(Bool.self, forKey: .ended) ?? false,
                scores: try c.decodeIfPresent(ScoreSnap.self, forKey: .scores)
            ))
        case "act":
            self = .act(Act(
                bid: try c.decodeIfPresent(Game.Bid.self, forKey: .bid),
                contract: try c.decodeIfPresent(Game.Bid.self, forKey: .contract),
                vist: try c.decodeIfPresent(Bool.self, forKey: .vist),
                opening: try c.decodeIfPresent(Bool.self, forKey: .opening),
                discard: try c.decodeIfPresent([Card].self, forKey: .discard),
                play: try c.decodeIfPresent(Card.self, forKey: .play),
                confirm: try c.decodeIfPresent(Bool.self, forKey: .confirm)
            ))
        default:
            throw PrefError("unknown game message type: \(t)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .state(let s):
            try c.encode("state", forKey: .t)
            try c.encode(s.field, forKey: .field)
            try c.encode(s.info, forKey: .info)
            try c.encode(s.yourTurn, forKey: .yourTurn)
            try c.encodeIfPresent(s.ask, forKey: .ask)
            try c.encode(s.badMove, forKey: .badMove)
            try c.encode(s.ended, forKey: .ended)
            try c.encodeIfPresent(s.scores, forKey: .scores)
        case .act(let a):
            try c.encode("act", forKey: .t)
            try c.encodeIfPresent(a.bid, forKey: .bid)
            try c.encodeIfPresent(a.contract, forKey: .contract)
            try c.encodeIfPresent(a.vist, forKey: .vist)
            try c.encodeIfPresent(a.opening, forKey: .opening)
            try c.encodeIfPresent(a.discard, forKey: .discard)
            try c.encodeIfPresent(a.play, forKey: .play)
            try c.encodeIfPresent(a.confirm, forKey: .confirm)
        }
    }
}
