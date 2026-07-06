import Foundation

open class HiddenPlay {

    public init() {}

    private func getNextTurn(_ game: Game) -> Int? {
        if game.deal.inPlay.containsKey(-1) && !game.deal.prikup.cards.isEmpty {
            // Первый заход с прикупом - ход остаётся у первого игрока
            let myNum = game.playerInTurn
            let prevNum = game.getPrevPlayer()
            let nextNum = game.getNextPlayer()
            let num = game.getFirstPlayer()
            switch num {
            case myNum: return 0
            case prevNum: return -1
            case nextNum: return 1
            default: break
            }
        }
        return nil
    }

    private func getResult(
        _ myMove: Card?, _ nextMove: Card?, _ prevMove: Card?, _ takes: Estimation, _ playColor: Int, _ trump: Int,
        _ rasklad: ColorRasklad?, _ aRasklad: Rasklad?, _ nextTurn: Int?, _ taken: [AIInfo.Take],
        _ firstMovePerformer: Int, _ contractor: Int?
    ) throws -> Double {
        let move = Move()
        move.myMove = myMove
        move.nextMove = nextMove
        move.prevMove = prevMove
        move.firstMovePerformer = firstMovePerformer
        takes.move = move

        takes.playHistory = try PlayHistory(taken, takes.move!)

        takes.trump = trump
        takes.contractor = contractor
        takes.cardsLeft = 9 - taken.count

        if let aRasklad = aRasklad {
            aRasklad.remove(takes.move!)

            try takes.calcRasklad(aRasklad)

            aRasklad.restore()
        } else {
            let cmove = Helper.getColorMove(takes.move!, playColor)

            rasklad!.remove(cmove)

            try takes.calcRasklad(rasklad!)

            rasklad!.restore()
        }

        takes.turn = try Helper.getTaker(myMove, prevMove, nextMove, playColor, trump)
        takes.prevTakes = 0.0
        takes.nextTakes = 0.0
        takes.myTakes = 0.0
        switch takes.turn {
        case -1: takes.prevTakes = 1.0
        case 1: takes.nextTakes = 1.0
        case 0: takes.myTakes = 1.0
        default: break
        }

        if let nextTurn = nextTurn {
            takes.turn = nextTurn
        }

        return try takes.getIntegral()
    }

    private func getEnumerator(_ info: AIInfo, _ color: Int, _ moveCard: Card?, _ game: Game) -> ColorRaskladEnumerator {
        let outCards = info.outOfPlayByColor[color]!.map { $0.value }
        let myCards = info.myHand.visibleHand!.cardByCoat[color]!.map { $0.value }

        var prevMax = info.prevHand.cardsCount
        var nextMax = info.nextHand.cardsCount

        for i in 0..<4 {
            if i == color {
                continue
            }
            if info.nextHand.colorNotExists.contains(i) {
                // На след. руке нет: значит все оставшиеся в игре карты на предыдущей руке или в прикупе
                var atHand = 8 - info.outOfPlayByColor[i]!.count - info.myHand.visibleHand!.cardByCoat[i]!.count
                atHand -= game.deal.prikup.cards.count
                if atHand > 0 {
                    prevMax -= atHand
                }
            }
            if info.prevHand.colorNotExists.contains(i) {
                var atHand = 8 - info.outOfPlayByColor[i]!.count - info.myHand.visibleHand!.cardByCoat[i]!.count
                atHand -= game.deal.prikup.cards.count
                if atHand > 0 {
                    nextMax -= atHand
                }
            }
        }

        if info.nextHand.colorNotExists.contains(color) {
            nextMax = 0
        }
        if info.prevHand.colorNotExists.contains(color) {
            prevMax = 0
        }
        let rEnumerator = ColorRaskladEnumerator(myCards, outCards, color, nextMax, prevMax)
        info.myHand.currentMove = moveCard
        return rEnumerator
    }

    open func createEstimation() -> Estimation {
        Estimation()
    }

    public func play(_ info: AIInfo, _ game: Game, _ allowedMoves: [Card]) throws -> Card {
        if allowedMoves.count == 1 {
            // Думать нечего
            return allowedMoves[0]
        }

        // Инициализируем переменные
        let myFirstMove = game.firstMovePerformer < 0
        let prikupInPlay = game.deal.inPlay.containsKey(-1)
        let myLastTurn = (game.deal.inPlay.count == 2 && !prikupInPlay) || (game.deal.inPlay.count == 3 && prikupInPlay)
        let calcAll = info.outOfPlay.count >= 5
        let nextTurn = getNextTurn(game)

        var color = game.deal.inPlayCoatColor

        // LinkedHashMap<Card, Double>: insertion-ordered
        var estimationKeys: [Card] = []
        var estimationValues: [Double] = []
        var turns: [Card] = []

        var rEnumerator: ColorRaskladEnumerator?
        var aEnumerator: RaskladEnumerator?
        var takes: Estimation
        // LinkedHashMap<Int, MutableList<Card>>: insertion-ordered
        var allowedColorOrder: [Int] = []
        var allowedMovesByColor: [Int: [Card]] = [:]
        for card in allowedMoves {
            if allowedMovesByColor[card.coatColor] == nil {
                allowedMovesByColor[card.coatColor] = []
                allowedColorOrder.append(card.coatColor)
            }
            allowedMovesByColor[card.coatColor]!.append(card)
        }

        let taken = info.outOfPlay

        var unknownPrikup = game.deal.prikup.cards.count - info.knownPrikup.count
        if unknownPrikup < 0 {
            unknownPrikup = 0
        }

        var contractor: Int?
        if game.currentGameType != .Raspasy {
            switch game.contractor {
            case game.getPrevPlayer(): contractor = -1
            case game.playerInTurn: contractor = 0
            case game.getNextPlayer(): contractor = 1
            default: contractor = nil
            }
        }

        for coat in allowedColorOrder {
            let moves = allowedMovesByColor[coat]!
            if myFirstMove {
                color = coat
            }

            takes = createEstimation()

            if !calcAll {
                // Рассчитываем для всех раскладов, кроме расклада по цвету захода и цвету выбранной карты
                for ci in 0..<4 {
                    if ci == color || ci == coat {
                        continue
                    }
                    rEnumerator = getEnumerator(info, ci, nil, game)
                    try takes.calcAllRasklads(ci, rEnumerator!)
                }
            }

            for card in moves {
                var integral = 0.0
                var nextMove: Card?
                var prevMove: Card?
                var rCnt = 0.0

                if !calcAll {
                    // Рассчитываем расклады для цвета сбрасываемой карты
                    if color != coat {
                        rEnumerator = getEnumerator(info, coat, card, game)
                        try takes.calcAllRasklads(coat, rEnumerator!)
                    }
                }

                let myMove: Card = card
                info.myHand.currentMove = card

                // Создаём перечисление раскладов
                var rasklad: ColorRasklad?
                var aRasklad: Rasklad?
                var colorEnumerator: ColorRaskladEnumerator?
                if !calcAll {
                    colorEnumerator = getEnumerator(info, color, card, game)
                    rasklad = colorEnumerator!.getNext()
                } else {
                    let myCards = game.deal.hands[game.playerInTurn].cards
                    var outCards: [Card] = []
                    for i in 0..<4 {
                        for outCard in info.outOfPlayByColor[i]! {
                            outCards.append(outCard)
                        }
                    }
                    aEnumerator = RaskladEnumerator(
                        myCards, outCards, info.nextHand.cardsCount, info.prevHand.cardsCount,
                        info.nextHand.colorNotExists, info.prevHand.colorNotExists,
                        unknownPrikup, contractor
                    )
                    aRasklad = aEnumerator!.getNext()
                }

                if rasklad == nil && aRasklad == nil {
                    throw PrefError("Расклад не найден!")
                }

                // Перебираем все расклады
                while rasklad != nil || aRasklad != nil {
                    if aRasklad != nil {
                        rasklad = aRasklad!.byColor[color]
                        colorEnumerator = nil
                    }
                    var res = 0.0
                    if myLastTurn {
                        // Мы ходим последние
                        nextMove = game.deal.inPlay[game.getNextPlayer()]
                        prevMove = game.deal.inPlay[game.getPrevPlayer()]
                        res = try getResult(myMove, nextMove, prevMove, takes, color, game.trump, rasklad, aRasklad, nextTurn, taken, game.firstMovePerformer, contractor)
                    } else if myFirstMove {
                        // Мы ходим первые
                        var worstRes = Double.greatestFiniteMagnitude

                        if rasklad!.nextHand.isEmpty {
                            nextMove = nil
                            if rasklad!.prevHand.isEmpty {
                                res = -100000000000000.0 // Никогда не ходим когда у противника ничего нет!
                                worstRes = res
                            } else {
                                // Перебираем все возможные ходы второго оппонента:
                                for prev in rasklad!.prevHand.toArray() {
                                    prevMove = Card(value: prev, coatColor: color)
                                    let cres = try getResult(myMove, nextMove, prevMove, takes, color, game.trump, rasklad, aRasklad, nextTurn, taken, game.firstMovePerformer, contractor)
                                    res += cres
                                    if worstRes > cres {
                                        worstRes = cres
                                    }
                                }
                            }
                        } else {
                            // Перебираем все возможные ходы первого оппонента:
                            for next in rasklad!.nextHand.toArray() {
                                nextMove = Card(value: next, coatColor: color)
                                if rasklad!.prevHand.isEmpty {
                                    prevMove = nil
                                    let cres = try getResult(myMove, nextMove, prevMove, takes, color, game.trump, rasklad, aRasklad, nextTurn, taken, game.firstMovePerformer, contractor)
                                    res += cres
                                    if worstRes > cres {
                                        worstRes = cres
                                    }
                                } else {
                                    // Перебираем все возможные ходы второго оппонента:
                                    for prev in rasklad!.prevHand.toArray() {
                                        prevMove = Card(value: prev, coatColor: color)
                                        let cres = try getResult(myMove, nextMove, prevMove, takes, color, game.trump, rasklad, aRasklad, nextTurn, taken, game.firstMovePerformer, contractor)
                                        res += cres
                                        if worstRes > cres {
                                            worstRes = cres
                                        }
                                    }
                                }
                            }
                        }
                        // За результат считаем худший для нас ответ противника.
                        res = worstRes
                    } else {
                        // Мы ходим вторые
                        prevMove = game.deal.inPlay[game.getPrevPlayer()]
                        if rasklad!.nextHand.isEmpty {
                            nextMove = nil
                            res = try getResult(myMove, nextMove, prevMove, takes, color, game.trump, rasklad, aRasklad, nextTurn, taken, game.firstMovePerformer, contractor)
                        } else {
                            var worstRes = Double.greatestFiniteMagnitude
                            // Перебираем все возможные ходы второго оппонента:
                            for next in rasklad!.nextHand.toArray() {
                                nextMove = Card(value: next, coatColor: color)
                                let cres = try getResult(myMove, nextMove, prevMove, takes, color, game.trump, rasklad, aRasklad, nextTurn, taken, game.firstMovePerformer, contractor)
                                res += cres
                                if worstRes > cres {
                                    worstRes = cres
                                }
                            }
                            res = worstRes
                        }
                    }

                    if aRasklad != nil {
                        rCnt += aRasklad!.probability
                        aRasklad = aEnumerator!.getNext()
                        if aRasklad == nil {
                            rasklad = nil
                        }
                    } else if rasklad != nil && colorEnumerator != nil {
                        rCnt += rasklad!.probability
                        rasklad = colorEnumerator!.getNext()
                    }
                    integral += res
                }

                integral /= rCnt

                estimationKeys.append(card)
                estimationValues.append(integral)
            }
        }

        // list = estimation.entries.sortedByDescending { it.value } (stable)
        let sortedIndices = estimationValues.indices.sorted { a, b in
            estimationValues[a] != estimationValues[b] ? estimationValues[a] > estimationValues[b] : a < b
        }
        let minValue = estimationValues[sortedIndices.first!]
        for idx in sortedIndices where estimationValues[idx] == minValue {
            turns.append(estimationKeys[idx])
        }
        return turns[Int.random(in: 0..<turns.count)]
    }
}
