import Foundation
import PrefEngine

/// A card placed on the virtual 480x716 table (the original WP7 canvas size).
/// All geometry below is a direct port of TableLayout.kt / GameMain.xaml.cs;
/// the view scales these units to the actual screen.
struct PlacedCard: Identifiable, Equatable {
    let card: Card? // nil = face down
    let hand: Int
    var x: Double
    var y: Double
    var isInPlay: Bool = false
    var isPrikup: Bool = false

    let id = UUID()

    static func == (lhs: PlacedCard, rhs: PlacedCard) -> Bool {
        lhs.id == rhs.id
    }
}

enum TableLayout {
    static let W = 480.0
    static let H = 716.0
    static let S0 = 70.0
    static let S1 = 79.0

    static func inPlayCoords(_ hand: Int) -> (Double, Double) {
        switch hand {
        case 1: return ((W / 2) - S1 / 1.36, (H / 2) - S1)
        case 2: return (W / 2, (H / 2) - S1)
        case 0: return ((W / 2) - (S1 / 2 / 1.36), H / 2)
        case -10: return ((W / 2) - S1 / 1.36, (H / 2) - S1) // первая карта из сброса
        case -20: return (W / 2, (H / 2) - S1) // вторая карта из сброса
        default: return ((W / 2) - (S1 / 2 / 1.36), (H / 2) - 2 * S1) // карта из прикупа
        }
    }

    static func outOfPlayCoords(_ hand: Int) -> (Double, Double) {
        switch hand {
        case 1: return (0.0, 0.0)
        case 2: return (W, 0.0)
        case 0: return (S1, H)
        default: return (0.0, 0.0)
        }
    }

    /// Start position for a card animated out of an invisible hand (port of AnimateCard).
    static func hiddenStartCoords(_ player: Int) -> (Double, Double) {
        switch player {
        case 2: return (W - S1, 3.0)
        case 1: return (3.0, 3.0)
        default: return ((W - S1) / 2, 3.0)
        }
    }

    /// Port of DrawOpenHand: lays out one hand's cards grouped by suit.
    static func handPlacements(_ cards: [Card], _ hand: Int, special: Bool, hidden: Bool) -> [PlacedCard] {
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
    static func computeField(
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
                res.append(contentsOf: handPlacements(deal.hands[hand].cards, hand, special: false, hidden: !deal.hands[hand].isVisible))
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
