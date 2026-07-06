import Foundation

/// A card placed on the virtual 480x716 table (the original WP7 canvas size).
/// All geometry below is a direct port of TableLayout.kt / GameMain.xaml.cs;
/// the view scales these units to the actual screen.
/// Codable: hosted multiplayer sends per-viewer placements to guests
/// (wire shape must match the Android PlacedCard byte-for-byte).
public struct PlacedCard: Identifiable, Equatable {
    public let card: Card? // nil = face down
    public let hand: Int
    public var x: Double
    public var y: Double
    public var isInPlay: Bool
    public var isPrikup: Bool

    public let id = UUID()

    public init(card: Card?, hand: Int, x: Double, y: Double, isInPlay: Bool = false, isPrikup: Bool = false) {
        self.card = card
        self.hand = hand
        self.x = x
        self.y = y
        self.isInPlay = isInPlay
        self.isPrikup = isPrikup
    }

    public static func == (lhs: PlacedCard, rhs: PlacedCard) -> Bool {
        lhs.id == rhs.id
    }
}

extension PlacedCard: Codable {
    private enum CodingKeys: String, CodingKey {
        case card, hand, x, y, isInPlay, isPrikup
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            card: try c.decodeIfPresent(Card.self, forKey: .card),
            hand: try c.decode(Int.self, forKey: .hand),
            x: try c.decode(Double.self, forKey: .x),
            y: try c.decode(Double.self, forKey: .y),
            isInPlay: try c.decodeIfPresent(Bool.self, forKey: .isInPlay) ?? false,
            isPrikup: try c.decodeIfPresent(Bool.self, forKey: .isPrikup) ?? false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // omit "card" when face-down (never emit explicit null)
        try c.encodeIfPresent(card, forKey: .card)
        try c.encode(hand, forKey: .hand)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(isInPlay, forKey: .isInPlay)
        try c.encode(isPrikup, forKey: .isPrikup)
    }
}

/// Immutable snapshot of everything the table UI needs to render texts.
/// Also the wire shape sent to multiplayer guests (matches Android TableInfo:
/// enums by name, Int-keyed maps as JSON objects with string keys).
public struct TableInfo: Codable {
    public var phase: GamePhase = .NotStarted
    public var names: [String] = ["", "", ""]
    public var dealer: Int = 0
    public var taken: [Int] = [0, 0, 0]
    public var currentGameType: GameType = .Raspasy
    public var contractor: Int = 0
    public var isVister: OrderedIntDict<Bool> = OrderedIntDict()
    public var curentBids: OrderedIntDict<Game.Bid> = OrderedIntDict()
    public var maxBid: Game.Bid?
    public var playerToTake: Int = 0
    public var playerInTurn: Int = 0
    public var gameResult: Calculation.GameResult?
    public var showPrikupBtn1: Bool = false
    public var showPrikupBtn2: Bool = false
    public var showTricksBtn: Bool = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case phase, names, dealer, taken, currentGameType, contractor, isVister,
             curentBids, maxBid, playerToTake, playerInTurn, gameResult,
             showPrikupBtn1, showPrikupBtn2, showTricksBtn
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phase = try c.decodeIfPresent(GamePhase.self, forKey: .phase) ?? .NotStarted
        names = try c.decodeIfPresent([String].self, forKey: .names) ?? ["", "", ""]
        dealer = try c.decodeIfPresent(Int.self, forKey: .dealer) ?? 0
        taken = try c.decodeIfPresent([Int].self, forKey: .taken) ?? [0, 0, 0]
        currentGameType = try c.decodeIfPresent(GameType.self, forKey: .currentGameType) ?? .Raspasy
        contractor = try c.decodeIfPresent(Int.self, forKey: .contractor) ?? 0
        isVister = try c.decodeIfPresent(OrderedIntDict<Bool>.self, forKey: .isVister) ?? OrderedIntDict()
        curentBids = try c.decodeIfPresent(OrderedIntDict<Game.Bid>.self, forKey: .curentBids) ?? OrderedIntDict()
        maxBid = try c.decodeIfPresent(Game.Bid.self, forKey: .maxBid)
        playerToTake = try c.decodeIfPresent(Int.self, forKey: .playerToTake) ?? 0
        playerInTurn = try c.decodeIfPresent(Int.self, forKey: .playerInTurn) ?? 0
        gameResult = try c.decodeIfPresent(Calculation.GameResult.self, forKey: .gameResult)
        showPrikupBtn1 = try c.decodeIfPresent(Bool.self, forKey: .showPrikupBtn1) ?? false
        showPrikupBtn2 = try c.decodeIfPresent(Bool.self, forKey: .showPrikupBtn2) ?? false
        showTricksBtn = try c.decodeIfPresent(Bool.self, forKey: .showTricksBtn) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(phase, forKey: .phase)
        try c.encode(names, forKey: .names)
        try c.encode(dealer, forKey: .dealer)
        try c.encode(taken, forKey: .taken)
        try c.encode(currentGameType, forKey: .currentGameType)
        try c.encode(contractor, forKey: .contractor)
        try c.encode(isVister, forKey: .isVister)
        try c.encode(curentBids, forKey: .curentBids)
        try c.encodeIfPresent(maxBid, forKey: .maxBid)
        try c.encode(playerToTake, forKey: .playerToTake)
        try c.encode(playerInTurn, forKey: .playerInTurn)
        try c.encodeIfPresent(gameResult, forKey: .gameResult)
        try c.encode(showPrikupBtn1, forKey: .showPrikupBtn1)
        try c.encode(showPrikupBtn2, forKey: .showPrikupBtn2)
        try c.encode(showTricksBtn, forKey: .showTricksBtn)
    }
}

public enum TableLayout {
    public static let W = 480.0
    public static let H = 716.0
    public static let S0 = 70.0
    public static let S1 = 79.0

    public static func inPlayCoords(_ hand: Int) -> (Double, Double) {
        switch hand {
        case 1: return ((W / 2) - S1 / 1.36, (H / 2) - S1)
        case 2: return (W / 2, (H / 2) - S1)
        case 0: return ((W / 2) - (S1 / 2 / 1.36), H / 2)
        case -10: return ((W / 2) - S1 / 1.36, (H / 2) - S1) // первая карта из сброса
        case -20: return (W / 2, (H / 2) - S1) // вторая карта из сброса
        default: return ((W / 2) - (S1 / 2 / 1.36), (H / 2) - 2 * S1) // карта из прикупа
        }
    }

    public static func outOfPlayCoords(_ hand: Int) -> (Double, Double) {
        switch hand {
        case 1: return (0.0, 0.0)
        case 2: return (W, 0.0)
        case 0: return (S1, H)
        default: return (0.0, 0.0)
        }
    }

    /// Start position for a card animated out of an invisible hand (port of AnimateCard).
    public static func hiddenStartCoords(_ player: Int) -> (Double, Double) {
        switch player {
        case 2: return (W - S1, 3.0)
        case 1: return (3.0, 3.0)
        default: return ((W - S1) / 2, 3.0)
        }
    }

    /// Port of DrawOpenHand: lays out one hand's cards grouped by suit.
    public static func handPlacements(_ cards: [Card], _ hand: Int, special: Bool, hidden: Bool) -> [PlacedCard] {
        var res: [PlacedCard] = []
        var row = 0.0
        var col = 0.0
        let max: Double
        var k = 1.36
        var coats = [0, 2, 1, 3]
        if cards.first(where: { $0.coatColor == 2 }) == nil {
            coats = [0, 3, 1, 2]
        }
        if cards.first(where: { $0.coatColor == 1 }) == nil {
            coats = [1, 2, 0, 3]
        }
        let dx: Double
        let dy: Double
        switch hand {
        case 1:
            dx = 10.0; dy = 42.0; max = 2.0
        case 2:
            dx = 345.0; dy = 42.0; max = 2.0
        default:
            if cards.count > 10 {
                dx = 155.0; dy = 512.0; max = 6.0; k = 1.5
            } else {
                dx = 171.0; dy = 512.0; max = 5.0
            }
        }
        for i in 0..<4 {
            let coat = coats[i]
            let list = cards.filter { $0.coatColor == coat }.sorted { $0.value > $1.value }
            if list.isEmpty {
                continue
            }
            for card in list {
                res.append(
                    PlacedCard(
                        card: hidden ? nil : card,
                        hand: hand,
                        x: dx + row * S1 / k,
                        y: dy + col * S1,
                        isInPlay: false,
                        isPrikup: special
                    )
                )
                row += 1
                if row >= max {
                    row = 0.0
                    col += 1
                }
            }
        }
        return res
    }

    /// Port of DrawField's card layer.
    /// - Parameters:
    ///   - discardSelection: cards the player has moved to the discard spots
    ///   - showPrikupHand: if 1 or 2, that hand is drawn together with possible talon cards
    public static func computeField(
        _ game: Game,
        discardSelection: [Card] = [],
        showPrikupHand: Int? = nil
    ) -> [PlacedCard] {
        var res: [PlacedCard] = []
        let deal = game.deal

        // Карты рук
        for hand in 0..<3 {
            if hand == showPrikupHand {
                var list = deal.hands[hand].cards
                let colorNotExists: [Int]
                if game.contractor == game.getPrevPlayer() {
                    colorNotExists = game.aIs[game.playerInTurn]?.prevHand.colorNotExists ?? []
                } else {
                    colorNotExists = game.aIs[game.playerInTurn]?.nextHand.colorNotExists ?? []
                }
                for card in deal.prikup.cards {
                    if !colorNotExists.contains(card.coatColor) {
                        list.append(card)
                    }
                }
                res.append(contentsOf: handPlacements(list, hand, special: true, hidden: false))
            } else {
                // seat 0 is always the local viewer here (single-player human or
                // multiplayer host); in hosted games hands[0].isVisible is false
                // so guests don't see it, but the host's own screen must
                let faceUp = hand == 0 || deal.hands[hand].isVisible
                res.append(contentsOf: handPlacements(deal.hands[hand].cards, hand, special: false, hidden: !faceUp))
            }
        }

        // Отобранные для сброса карты — переносим в центр
        if game.phase == .Discarding && !discardSelection.isEmpty {
            for (idx, card) in discardSelection.enumerated() {
                if let pos = res.firstIndex(where: { $0.hand == game.playerInTurn && $0.card?.id == card.id }) {
                    let c = inPlayCoords((idx + 1) * -10)
                    res[pos].x = c.0
                    res[pos].y = c.1
                }
            }
        }

        // Карты в игре
        for (key, card) in game.deal.inPlay.entries {
            let c = inPlayCoords(key)
            res.append(PlacedCard(card: card, hand: key, x: c.0, y: c.1, isInPlay: true))
        }

        // Прикуп
        if game.deal.prikup.isVisible {
            var k = 0
            for card in game.deal.prikup.cards {
                let x = (W / 2) - S1 / 1.36 + Double(k) * S1 / 1.36
                let y = (H / 2) - (S1 / 2)
                res.append(PlacedCard(card: card, hand: 3, x: x, y: y, isPrikup: true))
                k += 1
            }
        }
        return res
    }
}
