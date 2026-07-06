import Foundation

// Card and Hand are classes on purpose: the engine relies on reference
// identity and mutable shared lists (see AI.getContract mutating a Bid from
// the allowed list, Hand.cards shared with AIInfo). Do not convert to structs.
public final class Card: Codable {
    public var value: Int = 0
    public var coatColor: Int = 0

    /// Transient in Kotlin: never serialized.
    public var estimation: Double = 0.0

    private enum CodingKeys: String, CodingKey {
        case value, coatColor
    }

    public init(value: Int = 0, coatColor: Int = 0) {
        self.value = value
        self.coatColor = coatColor
    }

    public var id: Int {
        value + coatColor * 100
    }

    public func greaterThan(_ card: Card, trump: Int, initColor: Int) -> Bool {
        if self.coatColor != trump && card.coatColor == trump {
            return false
        }
        if self.coatColor == trump && card.coatColor != trump {
            return true
        }
        if self.coatColor != initColor && card.coatColor == initColor {
            return false
        }
        if self.coatColor == initColor && card.coatColor != initColor {
            return true
        }
        return self.value > card.value
    }
}

extension Card: CustomStringConvertible {
    public var description: String {
        var res: String
        switch value {
        case 14: res = "Т"
        case 13: res = "K"
        case 12: res = "Д"
        case 11: res = "В"
        default: res = String(value)
        }
        switch coatColor {
        case 0: res += "♠"
        case 1: res += "♣"
        case 2: res += "♦"
        case 3: res += "♥"
        default: break
        }
        return res
    }
}

public final class Hand: Codable {
    public var isVisible: Bool = false
    public var cards: [Card] = []
    public var taken: Int = 0

    /// Transient per-suit index rebuilt by `sort()`.
    public var cardByCoat: [Int: [Card]] = [:]

    private enum CodingKeys: String, CodingKey {
        case isVisible, cards, taken
    }

    public init() {}

    public func hasCoatColor(_ coatColor: Int) -> Bool {
        guard let list = cardByCoat[coatColor] else { return false }
        return !list.isEmpty
    }

    public func sort() {
        cardByCoat.removeAll()
        for i in 0..<4 {
            cardByCoat[i] = []
        }
        for card in cards {
            cardByCoat[card.coatColor]!.append(card)
        }
        for i in 0..<4 {
            cardByCoat[i] = cardByCoat[i]!.sorted { $0.value > $1.value }
        }
    }

    public func clone() -> Hand {
        let res = Hand()
        res.cards = self.cards
        res.isVisible = self.isVisible
        res.taken = self.taken
        res.sort()
        return res
    }
}

public final class Deal: Codable {
    public var hands: [Hand] = []
    public var prikup: Hand = Hand()
    public var inPlay: OrderedIntDict<Card> = OrderedIntDict()
    public var inPlayCoatColor: Int = 0

    private enum CodingKeys: String, CodingKey {
        case hands, prikup, inPlay, inPlayCoatColor
    }

    public init() {
        // The C# constructor always shuffled; deserialization overwrites this.
        shuffle()
    }

    /// Rebuild transient per-suit indexes after deserialization.
    public func restoreAfterLoad() {
        for hand in hands {
            hand.sort()
        }
        prikup.sort()
    }

    public var totalTaken: Int {
        hands.reduce(0) { $0 + $1.taken }
    }

    public func shuffle() {
        prikup = Hand()
        hands = []
        inPlay = OrderedIntDict()
        for i in 7...14 {
            for j in 0..<4 {
                prikup.cards.append(Card(value: i, coatColor: j))
            }
        }
        for _ in 0..<3 {
            let hand = Hand()
            hands.append(hand)
            for _ in 0..<10 {
                let pos = Int.random(in: 0..<prikup.cards.count)
                hand.cards.append(prikup.cards[pos])
                prikup.cards.remove(at: pos)
            }
            hand.sort()
        }
    }
}
