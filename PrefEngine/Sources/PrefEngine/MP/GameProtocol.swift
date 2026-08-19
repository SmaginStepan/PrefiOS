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
    /// Leningrad scoring doubles the pool conversion in the final settlement
    public var leningrad: Bool

    public init(names: [String], pulya: [Int], gora: [Int], visty: [[Int]], limit: Int, dealer: Int = 0, leningrad: Bool = false) {
        self.names = names
        self.pulya = pulya
        self.gora = gora
        self.visty = visty
        self.limit = limit
        self.dealer = dealer
        self.leningrad = leningrad
    }

    private enum CodingKeys: String, CodingKey {
        case names, pulya, gora, visty, limit, dealer, leningrad
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        names = try c.decode([String].self, forKey: .names)
        pulya = try c.decode([Int].self, forKey: .pulya)
        gora = try c.decode([Int].self, forKey: .gora)
        visty = try c.decodeIfPresent([[Int]].self, forKey: .visty) ?? []
        limit = try c.decode(Int.self, forKey: .limit)
        dealer = try c.decodeIfPresent(Int.self, forKey: .dealer) ?? 0
        leningrad = try c.decodeIfPresent(Bool.self, forKey: .leningrad) ?? false
    }
}

/// A pending agreement offer, viewer-relative.
public struct OfferSnap: Codable {
    /// display name of the player who made the offer
    public var by: String
    /// the agreed final trick counts (index = viewer-relative seat)
    public var taken: [Int]
    /// this viewer must answer accept/decline
    public var youRespond: Bool

    public init(by: String, taken: [Int], youRespond: Bool = false) {
        self.by = by
        self.taken = taken
        self.youRespond = youRespond
    }

    private enum CodingKeys: String, CodingKey {
        case by, taken, youRespond
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        by = try c.decodeIfPresent(String.self, forKey: .by) ?? ""
        taken = try c.decodeIfPresent([Int].self, forKey: .taken) ?? []
        youRespond = try c.decodeIfPresent(Bool.self, forKey: .youRespond) ?? false
    }
}

/// One completed trick, viewer-relative (-1 prev / 0 you / 1 next).
public struct TakeSnap: Codable {
    public var first: Int
    public var taker: Int
    public var my: Card?
    public var prev: Card?
    public var next: Card?
    public var prikup: Card?

    public init(first: Int, taker: Int, my: Card? = nil, prev: Card? = nil, next: Card? = nil, prikup: Card? = nil) {
        self.first = first
        self.taker = taker
        self.my = my
        self.prev = prev
        self.next = next
        self.prikup = prikup
    }

    private enum CodingKeys: String, CodingKey {
        case first, taker, my, prev, next, prikup
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        first = try c.decodeIfPresent(Int.self, forKey: .first) ?? 0
        taker = try c.decodeIfPresent(Int.self, forKey: .taker) ?? 0
        my = try c.decodeIfPresent(Card.self, forKey: .my)
        prev = try c.decodeIfPresent(Card.self, forKey: .prev)
        next = try c.decodeIfPresent(Card.self, forKey: .next)
        prikup = try c.decodeIfPresent(Card.self, forKey: .prikup)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(first, forKey: .first)
        try c.encode(taker, forKey: .taker)
        try c.encodeIfPresent(my, forKey: .my)
        try c.encodeIfPresent(prev, forKey: .prev)
        try c.encodeIfPresent(next, forKey: .next)
        try c.encodeIfPresent(prikup, forKey: .prikup)
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
        /// the score sheet everyone must look at (deal end / game end)
        public var scores: ScoreSnap?
        /// completed tricks of the deal, for the guest tricks viewer
        public var takes: [TakeSnap]?
        /// the layout-and-discard view (contractor's open hand + possible talon)
        public var layout: [PlacedCard]?
        /// current standings for the on-demand score peek
        public var standings: ScoreSnap?
        /// an agreement offer is pending: the table is frozen
        public var offer: OfferSnap?
        /// name of the player who just declined an offer (one broadcast only)
        public var offerDeclined: String?

        public init(
            field: [PlacedCard],
            info: TableInfo,
            yourTurn: Bool,
            ask: Ask? = nil,
            badMove: Bool = false,
            ended: Bool = false,
            scores: ScoreSnap? = nil,
            takes: [TakeSnap]? = nil,
            layout: [PlacedCard]? = nil,
            standings: ScoreSnap? = nil,
            offer: OfferSnap? = nil,
            offerDeclined: String? = nil
        ) {
            self.field = field
            self.info = info
            self.yourTurn = yourTurn
            self.ask = ask
            self.badMove = badMove
            self.ended = ended
            self.scores = scores
            self.takes = takes
            self.layout = layout
            self.standings = standings
            self.offer = offer
            self.offerDeclined = offerDeclined
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
        /// propose an agreement: final trick counts, viewer-relative
        public var offer: [Int]?
        /// the offer is «остальные мои» (raspasy/misère special)
        public var restMine: Bool?
        /// answer to a pending offer
        public var agree: Bool?
        /// the player switched client-side auto-confirm on/off
        public var autoMode: Bool?

        public init(
            bid: Game.Bid? = nil,
            contract: Game.Bid? = nil,
            vist: Bool? = nil,
            opening: Bool? = nil,
            discard: [Card]? = nil,
            play: Card? = nil,
            confirm: Bool? = nil,
            offer: [Int]? = nil,
            restMine: Bool? = nil,
            agree: Bool? = nil,
            autoMode: Bool? = nil
        ) {
            self.bid = bid
            self.contract = contract
            self.vist = vist
            self.opening = opening
            self.discard = discard
            self.play = play
            self.confirm = confirm
            self.offer = offer
            self.restMine = restMine
            self.agree = agree
            self.autoMode = autoMode
        }
    }

    case state(State)
    case act(Act)
}

extension GameMsg: Codable {
    private enum CodingKeys: String, CodingKey {
        case t
        // state
        case field, info, yourTurn, ask, badMove, ended, scores, takes, layout, standings, offerDeclined
        // act (offer/agree are shared with state's offer key)
        case bid, contract, vist, opening, discard, play, confirm, offer, restMine, agree, autoMode
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
                scores: try c.decodeIfPresent(ScoreSnap.self, forKey: .scores),
                takes: try c.decodeIfPresent([TakeSnap].self, forKey: .takes),
                layout: try c.decodeIfPresent([PlacedCard].self, forKey: .layout),
                standings: try c.decodeIfPresent(ScoreSnap.self, forKey: .standings),
                offer: try c.decodeIfPresent(OfferSnap.self, forKey: .offer),
                offerDeclined: try c.decodeIfPresent(String.self, forKey: .offerDeclined)
            ))
        case "act":
            self = .act(Act(
                bid: try c.decodeIfPresent(Game.Bid.self, forKey: .bid),
                contract: try c.decodeIfPresent(Game.Bid.self, forKey: .contract),
                vist: try c.decodeIfPresent(Bool.self, forKey: .vist),
                opening: try c.decodeIfPresent(Bool.self, forKey: .opening),
                discard: try c.decodeIfPresent([Card].self, forKey: .discard),
                play: try c.decodeIfPresent(Card.self, forKey: .play),
                confirm: try c.decodeIfPresent(Bool.self, forKey: .confirm),
                offer: try c.decodeIfPresent([Int].self, forKey: .offer),
                restMine: try c.decodeIfPresent(Bool.self, forKey: .restMine),
                agree: try c.decodeIfPresent(Bool.self, forKey: .agree),
                autoMode: try c.decodeIfPresent(Bool.self, forKey: .autoMode)
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
            try c.encodeIfPresent(s.takes, forKey: .takes)
            try c.encodeIfPresent(s.layout, forKey: .layout)
            try c.encodeIfPresent(s.standings, forKey: .standings)
            try c.encodeIfPresent(s.offer, forKey: .offer)
            try c.encodeIfPresent(s.offerDeclined, forKey: .offerDeclined)
        case .act(let a):
            try c.encode("act", forKey: .t)
            try c.encodeIfPresent(a.bid, forKey: .bid)
            try c.encodeIfPresent(a.contract, forKey: .contract)
            try c.encodeIfPresent(a.vist, forKey: .vist)
            try c.encodeIfPresent(a.opening, forKey: .opening)
            try c.encodeIfPresent(a.discard, forKey: .discard)
            try c.encodeIfPresent(a.play, forKey: .play)
            try c.encodeIfPresent(a.confirm, forKey: .confirm)
            try c.encodeIfPresent(a.offer, forKey: .offer)
            try c.encodeIfPresent(a.restMine, forKey: .restMine)
            try c.encodeIfPresent(a.agree, forKey: .agree)
            try c.encodeIfPresent(a.autoMode, forKey: .autoMode)
        }
    }
}
