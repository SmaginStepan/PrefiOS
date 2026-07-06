import Foundation

public final class Rasklad {
    public var byColor: [Int: ColorRasklad] = [:]
    public var probability: Double = 1.0

    public init() {}

    public func fromGameCheat(_ game: Game) {
        probability = 1.0
        byColor = [:]
        for i in 0..<4 {
            let cr = ColorRasklad()
            cr.coatColor = i
            cr.probability = 1.0
            cr.myHand = IntList(game.deal.hands[game.playerInTurn].cardByCoat[i]!.map { $0.value }.sorted())
            cr.nextHand = IntList(game.deal.hands[game.getNextPlayer()].cardByCoat[i]!.map { $0.value }.sorted())
            cr.prevHand = IntList(game.deal.hands[game.getPrevPlayer()].cardByCoat[i]!.map { $0.value }.sorted())
            byColor[i] = cr
        }
    }

    public func fromPlay(_ info: AIInfo) {
        probability = 1.0
        byColor = [:]
        for i in 0..<4 {
            var prevHand: IntList? = info.prevHand.isVisible
                ? IntList(info.prevHand.visibleHand!.cardByCoat[i]!.map { $0.value }.sorted())
                : nil
            var nextHand: IntList? = info.nextHand.isVisible
                ? IntList(info.nextHand.visibleHand!.cardByCoat[i]!.map { $0.value }.sorted())
                : nil
            let myHand = IntList(info.myHand.visibleHand!.cardByCoat[i]!.map { $0.value }.sorted())

            if prevHand == nil {
                let list = IntList()
                for v in 7..<15 {
                    if !myHand.contains(v) && !nextHand!.contains(v) && !info.prevHand.colorNotExists.contains(i) && info.outOfPlayByColor[i]!.first(where: { $0.value == v }) == nil {
                        list.append(v)
                    }
                }
                prevHand = list
            } else if nextHand == nil {
                let list = IntList()
                for v in 7..<15 {
                    if !myHand.contains(v) && !prevHand!.contains(v) && !info.nextHand.colorNotExists.contains(i) && info.outOfPlayByColor[i]!.first(where: { $0.value == v }) == nil {
                        list.append(v)
                    }
                }
                nextHand = list
            }
            let cr = ColorRasklad()
            cr.coatColor = i
            cr.probability = 1.0
            cr.myHand = myHand
            cr.nextHand = nextHand!
            cr.prevHand = prevHand!
            byColor[i] = cr
        }
    }

    public var removed: [Move] {
        // java.util.ArrayDeque.toList(): head-first (most recently pushed first).
        removedStack.reversed()
    }

    private var removedStack: [Move] = []

    public func remove(_ move: Move, _ cardsAlreadyRemoved: Bool = false) {
        if !cardsAlreadyRemoved {
            for color in 0..<4 where byColor[color] != nil {
                let cmove = Helper.getColorMove(move.myMove, move.prevMove, move.nextMove, color)
                byColor[color]!.remove(cmove)
            }
        }
        removedStack.append(move)
    }

    @discardableResult
    public func removeCard(_ card: Card, _ hand: Int) throws -> Bool {
        switch hand {
        case 0: return byColor[card.coatColor]!.myHand.removeValue(card.value)
        case -1: return byColor[card.coatColor]!.prevHand.removeValue(card.value)
        case 1: return byColor[card.coatColor]!.nextHand.removeValue(card.value)
        default: throw PrefError("Неверно указана рука!")
        }
    }

    public func addCard(_ card: Card, _ hand: Int) throws {
        let list: IntList
        switch hand {
        case 0: list = byColor[card.coatColor]!.myHand
        case -1: list = byColor[card.coatColor]!.prevHand
        case 1: list = byColor[card.coatColor]!.nextHand
        default: throw PrefError("Неверно указана рука!")
        }
        var pos = 0
        while pos < list.count {
            if list[pos] > card.value {
                break
            }
            pos += 1
        }
        list.insert(card.value, at: pos)
    }

    public func popLast(_ cardsAlreadyRemoved: Bool = false) -> Move {
        if !cardsAlreadyRemoved {
            for color in 0..<4 where byColor[color] != nil {
                byColor[color]!.popLast()
            }
        }
        return removedStack.removeLast()
    }

    public func restore() {
        for color in 0..<4 where byColor[color] != nil {
            byColor[color]!.restore()
        }
    }

    private func checkColorInHand(_ hand: Int, _ color: Int) throws -> Bool {
        let list: IntList
        switch hand {
        case -1: list = byColor[color]!.prevHand
        case 0: list = byColor[color]!.myHand
        case 1: list = byColor[color]!.nextHand
        default: throw PrefError("Неверно задана рука!")
        }
        for i in 0..<list.count {
            if list[i] > 0 {
                return true
            }
        }
        return false
    }

    /// Получаем карты на руке
    /// - Parameters:
    ///   - hand: рука
    ///   - distinct: если true - получаем только те, между которыми есть карты на других руках
    public func getCardsInHand(_ hand: Int, _ distinct: Bool, _ color: Int? = nil, _ maxCard: Card? = nil) -> [Card] {
        var allCardInHand: [Card] = []
        for c in 0..<4 {
            if let color = color, color != c {
                continue
            }
            guard let cr = byColor[c] else { continue }
            var list: [Int] = []
            var others: [Int]?
            if hand == -1 {
                list = cr.prevHand.toArray()
                if distinct {
                    var o = cr.myHand.toArray()
                    o.append(contentsOf: cr.nextHand.toArray())
                    others = o
                }
            } else if hand == 0 {
                list = cr.myHand.toArray()
                if distinct {
                    var o = cr.prevHand.toArray()
                    o.append(contentsOf: cr.nextHand.toArray())
                    others = o
                }
            } else if hand == 1 {
                list = cr.nextHand.toArray()
                if distinct {
                    var o = cr.prevHand.toArray()
                    o.append(contentsOf: cr.myHand.toArray())
                    others = o
                }
            }
            if distinct {
                if let maxCard = maxCard, maxCard.coatColor == c {
                    others!.append(maxCard.value)
                }
                list = list.sorted()
            }
            var v0 = 0
            for v in list {
                if v > 0 {
                    var skip = false
                    if distinct, let others = others, v0 > 0 {
                        skip = true
                        if v0 + 1 < v {
                            for i in (v0 + 1)..<v {
                                if others.contains(i) {
                                    skip = false
                                    break
                                }
                            }
                        }
                    }
                    if !skip {
                        allCardInHand.append(Card(value: v, coatColor: c))
                        v0 = v
                    }
                }
            }
        }
        return allCardInHand
    }

    public func getAllowedMoves(_ currentMove: Move, _ trump: Int, _ distict: Bool) throws -> [Card] {
        // Определяем цвет и руку, с которой надо ходить
        var color: Int?
        var hand = 0
        if currentMove.firstMove == nil {
            switch currentMove.firstMovePerformer {
            case -1: hand = -1
            case 0: hand = 0
            case 1: hand = 1
            default: hand = 0
            }
        } else if currentMove.secondMove == nil {
            color = currentMove.firstMove!.coatColor
            switch currentMove.firstMovePerformer {
            case -1: hand = 0
            case 0: hand = 1
            case 1: hand = -1
            default: hand = 0
            }
        } else if currentMove.thirdMove == nil {
            color = currentMove.firstMove!.coatColor
            switch currentMove.firstMovePerformer {
            case -1: hand = 1
            case 0: hand = -1
            case 1: hand = 0
            default: hand = 0
            }
        } else {
            throw PrefError("Все ходы использованы!")
        }

        let maxCard: Card?

        if color != nil {
            if try !checkColorInHand(hand, color!) {
                color = trump
                if trump < 0 || trump > 3 {
                    color = nil
                } else if try !checkColorInHand(hand, trump) {
                    color = nil
                }
            }
        }
        maxCard = color == nil ? nil : currentMove.getMaxCard(trump)
        return getCardsInHand(hand, distict, color, maxCard)
    }
}
