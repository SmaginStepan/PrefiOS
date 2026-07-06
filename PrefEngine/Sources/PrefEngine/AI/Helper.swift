import Foundation

public enum Helper {

    public static func getTaker(_ move: Move, _ trump: Int = -1) throws -> Int {
        try getTaker(move.myMove, move.prevMove, move.nextMove, move.playColor, trump)
    }

    public static func getTaker(_ myMove: Card?, _ prevMove: Card?, _ nextMove: Card?, _ playColor: Int, _ trump: Int = -1) throws -> Int {
        let myVal = myMove == nil ? 0 : (myMove!.coatColor == trump ? myMove!.value + 10 : (myMove!.coatColor == playColor ? myMove!.value : 0))
        let prevVal = prevMove == nil ? 0 : (prevMove!.coatColor == trump ? prevMove!.value + 10 : (prevMove!.coatColor == playColor ? prevMove!.value : 0))
        let nextVal = nextMove == nil ? 0 : (nextMove!.coatColor == trump ? nextMove!.value + 10 : (nextMove!.coatColor == playColor ? nextMove!.value : 0))
        if myVal > prevVal && myVal > nextVal {
            return 0
        }
        if prevVal > myVal && prevVal > nextVal {
            return -1
        }
        if nextVal > myVal && nextVal > prevVal {
            return 1
        }
        throw PrefError("Не может быть одинаковых карт!")
    }

    public static func getMaxCard(_ myMove: Card?, _ prevMove: Card?, _ nextMove: Card?, _ playColor: Int, _ trump: Int = -1) -> Card? {
        let myVal = myMove == nil ? 0 : (myMove!.coatColor == trump ? myMove!.value + 10 : (myMove!.coatColor == playColor ? myMove!.value : 0))
        let prevVal = prevMove == nil ? 0 : (prevMove!.coatColor == trump ? prevMove!.value + 10 : (prevMove!.coatColor == playColor ? prevMove!.value : 0))
        let nextVal = nextMove == nil ? 0 : (nextMove!.coatColor == trump ? nextMove!.value + 10 : (nextMove!.coatColor == playColor ? nextMove!.value : 0))
        if myVal > prevVal && myVal > nextVal {
            return myMove
        }
        if prevVal > myVal && prevVal > nextVal {
            return prevMove
        }
        if nextVal > myVal && nextVal > prevVal {
            return nextMove
        }
        return nil
    }

    public static func getColorMove(_ move: Move, _ color: Int) -> ColoredMove {
        getColorMove(move.myMove, move.prevMove, move.nextMove, color)
    }

    public static func getColorMove(_ myMove: Card?, _ prevMove: Card?, _ nextMove: Card?, _ color: Int) -> ColoredMove {
        let move = ColoredMove()
        move.myMove = (myMove == nil || myMove!.coatColor != color) ? 0 : myMove!.value
        move.prevMove = (prevMove == nil || prevMove!.coatColor != color) ? 0 : prevMove!.value
        move.nextMove = (nextMove == nil || nextMove!.coatColor != color) ? 0 : nextMove!.value
        return move
    }

    private static func getMiserCoatTakes(_ info: AIInfo, _ color: Int) throws -> Double {
        let est = MiserEstimation()
        est.cardsLeft = 10
        est.contractor = 0
        est.isHidden = true
        est.trump = -1
        est.turn = 0
        let myCards = info.myHand.visibleHand!.cardByCoat[color]!.map { $0.value }
        try est.calcAllRasklads(color, ColorRaskladEnumerator(myCards, [], color, 10, 10))
        return est.colors[color]!.takes
    }

    private final class MiserIntegralResult {
        var integral: Double = 0.0
        var notNeeded: Bool = false
        var unreal: Bool = false
    }

    private static func getMiserIntegral(_ cards: [Card], _ firstCard: Card, _ secondCard: Card) throws -> MiserIntegralResult {
        let result = MiserIntegralResult()
        let est = MiserEstimation()
        est.cardsLeft = 10
        est.contractor = 0
        est.isHidden = true
        est.trump = -1
        est.turn = 0
        for c in 0..<4 {
            var myCards = cards.filter { $0.coatColor == c }.map { $0.value }.sorted()
            var outCards: [Int] = []
            try est.calcAllRasklads(c, ColorRaskladEnumerator(myCards, outCards, c, 10, 10))
            let takes = est.colors[c]!.takes
            if firstCard.coatColor == c || secondCard.coatColor == c {
                if firstCard.coatColor == c {
                    outCards.append(firstCard.value)
                }
                if secondCard.coatColor == c {
                    outCards.append(secondCard.value)
                }
                myCards = myCards.filter { v in (v != firstCard.value || firstCard.coatColor != c) && (v != secondCard.value || secondCard.coatColor != c) }
                try est.calcAllRasklads(c, ColorRaskladEnumerator(myCards, outCards, c, 10, 10))
                let outTakes = est.colors[c]!.takes
                if takes <= outTakes {
                    result.notNeeded = true
                    if takes < outTakes {
                        result.unreal = true
                    } else if outCards.count == 2 {
                        // Попробуем скинуть только старшую
                        let sortedOut = outCards.sorted()
                        myCards.append(sortedOut[0])
                        try est.calcAllRasklads(c, ColorRaskladEnumerator(myCards, sortedOut, c, 10, 10))
                        let oneTakes = est.colors[c]!.takes
                        if oneTakes <= outTakes {
                            result.notNeeded = true
                        }
                    }
                }
            }
        }
        result.integral = try est.getIntegral()
        return result
    }

    public static func getPotentialDiscards(_ info: AIInfo, _ game: Game) throws -> [PotentialDiscard]? {
        if game.currentGameType != .Miser {
            return nil
        }
        let cards = game.deal.hands[game.playerInTurn].cards.sorted { $0.id < $1.id }
        var list: [PotentialDiscard] = []
        var firstCard: Card
        var secondCard: Card
        for i in 0..<11 {
            firstCard = cards[i]
            if info.myHand.colorNotExists.contains(firstCard.coatColor) {
                continue
            }
            for j in (i + 1)..<12 {
                secondCard = cards[j]
                if info.myHand.colorNotExists.contains(secondCard.coatColor) {
                    continue
                }

                let discard = PotentialDiscard()
                discard.firstCard = firstCard
                discard.secondCard = secondCard
                discard.probability = 1.0
                let res = try getMiserIntegral(cards, firstCard, secondCard)
                if res.unreal {
                    continue
                }
                if res.integral < 0 {
                    discard.probability = 1 / (res.integral * res.integral)
                    if res.notNeeded {
                        discard.probability /= 10000
                    }
                } else {
                    // Если есть расклад при котором мы гарантированно не берём взяток...
                    discard.probability = 1.0
                    list.removeAll()
                    list.append(discard)
                    // Возвращаем его
                    return list
                }

                list.append(discard)
            }
        }

        if AiDebug.enabled {
            logDiscards(list)
        }

        return list
    }

    public static func logDiscards(_ discards: [PotentialDiscard]) {
        var res = ""
        let sum = discards.reduce(0.0) { $0 + $1.probability }
        for discard in discards.sorted(by: { $0.probability > $1.probability }) {
            let first = discard.firstCard.map { "\($0)" } ?? "?"
            let second = discard.secondCard.map { "\($0)" } ?? "?"
            res += "\(first) \(second) \(discard.probability) \(discard.probability * 100.0 / sum)%  hash=\(discard.hash ?? "?")\r\n"
        }
        let ss = res.replacingOccurrences(of: "\r", with: " ").split(separator: "\n", omittingEmptySubsequences: false)
        for s in ss {
            AiDebug.log(String(s))
        }
    }

    public static func getCards(_ cards: [Card]) -> String {
        var res = ""
        for card in cards.sorted(by: { $0.coatColor * 10 + $0.value < $1.coatColor * 10 + $1.value }) {
            let s = "\(card)"
            res += String(repeating: " ", count: Swift.max(0, 4 - s.count)) + s
        }
        return res
    }

    public static func logRasklad(_ rasklad: Rasklad) {
        let ss = getRasklad(rasklad).replacingOccurrences(of: "\r", with: " ").split(separator: "\n", omittingEmptySubsequences: false)
        for s in ss {
            AiDebug.log(String(s))
        }
    }

    public static func getRasklad(_ rasklad: Rasklad) -> String {
        func pad(_ s: String, _ width: Int) -> String {
            s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
        }
        var res = ""
        var rows: [[String]] = []
        for hand in [-1, 0, 1] {
            var row: [String] = []
            for color in 0..<4 {
                row.append(getCards(rasklad.getCardsInHand(hand, false, color)))
            }
            rows.append(row)
        }
        res += "-1 = \(pad(rows[0][0], 20)) \(pad(rows[0][1], 20)) \(pad(rows[0][2], 20)) \(pad(rows[0][3], 120))\r\n"
        res += " 0 = \(pad(rows[1][0], 20)) \(pad(rows[1][1], 20)) \(pad(rows[1][2], 20)) \(pad(rows[1][3], 20)) \r\n"
        res += " 1 = \(pad(rows[2][0], 20)) \(pad(rows[2][1], 20)) \(pad(rows[2][2], 20)) \(pad(rows[2][3], 20)) \r\n"
        res += "\n"
        return res
    }
}
