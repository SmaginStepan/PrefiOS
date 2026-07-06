import Foundation

public final class GameSituation {

    public var potentialDiscards: [PotentialDiscard]?

    private var move: Move

    public var rasklad: Rasklad

    public var contractor: Int = 0

    private let gamePlay: OpenPlay

    private let contractorColorNotExists: [Int]

    private var playerToMove: Int

    private let alreadyTaken: Taken

    private let trump: Int

    public var calculated = 0
    public var skipped = 0
    public var maxwidth = 0
    private var cardsLeft = 0

    private func nextPlayer() {
        playerToMove += 1
        if playerToMove > 1 {
            playerToMove = -1
        }
    }

    private func prevPlayer() {
        playerToMove -= 1
        if playerToMove < -1 {
            playerToMove = 1
        }
    }

    private var cardMoves: [Card]

    public var maxDepth: Int = 0

    private func moveCard(_ card: Card) throws {
        if move.firstMove == nil {
            move.firstMove = card
            try rasklad.removeCard(card, playerToMove)
            cardMoves.append(card)
            nextPlayer()
        } else if move.secondMove == nil {
            move.secondMove = card
            try rasklad.removeCard(card, playerToMove)
            cardMoves.append(card)
            nextPlayer()
        } else if move.thirdMove == nil {
            move.thirdMove = card
            try rasklad.removeCard(card, playerToMove)
            cardMoves.append(card)
            // Текущий круг закончен - переходим к следующему...
            maxDepth -= 1
            cardsLeft -= 1
            rasklad.remove(move, true)
            let next = try Helper.getTaker(move, trump)
            try alreadyTaken.addTake(next)
            move = Move()
            move.firstMovePerformer = next
            playerToMove = next
        }
    }

    private func undoCard() throws {
        let lastCard = cardMoves.removeLast()
        if move.thirdMove != nil {
            throw PrefError("Это невозможно, так как при заполнении хода мы сразу переходим к следующему!")
        } else if move.secondMove != nil {
            move.secondMove = nil
            prevPlayer()
            try rasklad.addCard(lastCard, playerToMove)
        } else if move.firstMove != nil {
            move.firstMove = nil
            prevPlayer()
            try rasklad.addCard(lastCard, playerToMove)
        } else {
            maxDepth += 1
            cardsLeft += 1
            // Вытаскиваем последний ход
            move = rasklad.popLast(true)
            try alreadyTaken.removeTake(move.getTaker(trump))
            move.thirdMove = nil
            playerToMove = move.firstMovePerformer
            prevPlayer()
            try rasklad.addCard(lastCard, playerToMove)
        }
    }

    public var isMaximizing: Bool {
        gamePlay.isMaximizing(playerToMove, contractor)
    }

    private func calcEstimation() throws -> Double {
        let est = gamePlay.createEstimation()
        est.contractor = contractor
        try est.calcRasklad(rasklad)
        est.turn = playerToMove
        est.myTakes = alreadyTaken.myTakes
        est.nextTakes = alreadyTaken.nextTakes
        est.prevTakes = alreadyTaken.prevTakes
        est.trump = trump
        est.cardsLeft = cardsLeft
        return try est.getIntegral()
    }

    public func getDistinctMoves() throws -> [Card] {
        try rasklad.getAllowedMoves(move, trump, true)
    }

    public func sortByEstimation(_ cards: [Card], _ descending: Bool) -> [Card] {
        if descending {
            return cards.enumerated().sorted { (a, b) in
                a.element.estimation != b.element.estimation ? a.element.estimation > b.element.estimation : a.offset < b.offset
            }.map { $0.element }
        } else {
            return cards.enumerated().sorted { (a, b) in
                a.element.estimation != b.element.estimation ? a.element.estimation < b.element.estimation : a.offset < b.offset
            }.map { $0.element }
        }
    }

    public func getEstimation(_ min: Double, _ max: Double, _ firstLevel: Bool, _ preEstimate: Bool = false, _ width: Int = 0) throws -> EstimationWithCard? {
        let cards = try rasklad.getAllowedMoves(move, trump, true)
        let isMaximizing = self.isMaximizing
        if cards.isEmpty {
            throw PrefError("Что-то у нас карт не хватает... не к добру")
        }

        let res = EstimationWithCard()
        var stop = false
        if move.secondMove != nil && move.thirdMove == nil {
            // Это третья рука - обязательное условие для оценки!
            if maxDepth == 0 || preEstimate {
                // Усё... время вышло, пора оценивать
                stop = true
            }
        }

        res.estimation = isMaximizing ? -Double.greatestFiniteMagnitude : Double.greatestFiniteMagnitude
        var bestCards: [Card]? = nil
        if firstLevel {
            bestCards = []
        }

        var newMax = max
        var newMin = min

        for card in cards {
            var est: Double
            if stop {
                calculated += 1
                try moveCard(card)
                est = try calcEstimation()
                try undoCard()
                if maxwidth < width * cards.count {
                    maxwidth = width * cards.count
                }
            } else {
                try moveCard(card)
                let ewc = try getEstimation(-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, false, preEstimate, width * cards.count)
                try undoCard()
                guard let ewc = ewc else {
                    if preEstimate || calculated == 0 {
                        throw PrefError("Это предварительный расчёт!!!")
                    }
                    continue
                }
                est = ewc.estimation
                if !preEstimate {
                    if (est > max && isMaximizing) || (est < min && !isMaximizing) {
                        skipped += 1
                        if firstLevel || calculated == 0 {
                            throw PrefError("NULL на первом уровне WTF!")
                        }
                        return nil
                    }
                }
            }

            if isMaximizing && est > res.estimation {
                if !preEstimate && est > newMin {
                    newMin = est
                }
                res.estimation = est
                if firstLevel {
                    bestCards!.removeAll()
                    bestCards!.append(card)
                }
            } else if !isMaximizing && est < res.estimation {
                if !preEstimate && est < newMax {
                    newMax = est
                }
                res.estimation = est
                if firstLevel {
                    bestCards!.removeAll()
                    bestCards!.append(card)
                }
            } else if firstLevel && est == res.estimation {
                bestCards!.append(card)
            }
        }

        if firstLevel {
            res.bestCard = bestCards![Int.random(in: 0..<bestCards!.count)]
            // Карты надо вернуть только для первого уровня
        }
        if res.estimation == -Double.greatestFiniteMagnitude || res.estimation == Double.greatestFiniteMagnitude {
            if preEstimate || firstLevel || calculated == 0 {
                throw PrefError("Не могли пропустить вариант!")
            }
            return nil // Мы пропустили все варианты...
        }
        return res
    }

    public init(_ game: Game, _ info: AIInfo, _ gamePlay: OpenPlay) {
        self.gamePlay = gamePlay

        if game.playerInTurn == game.contractor {
            contractor = 0
        } else if game.contractor == game.getPrevPlayer() {
            contractor = -1
        } else if game.contractor == game.getNextPlayer() {
            contractor = 1
        } else {
            contractor = 0
        }

        potentialDiscards = gamePlay.getPotentialDiscard(info)

        trump = game.trump

        rasklad = Rasklad()
        rasklad.fromPlay(info)

        alreadyTaken = Taken()

        contractorColorNotExists = info.myHand.colorNotExists

        move = Move()
        move.prevMove = info.prevHand.currentMove
        move.myMove = nil
        move.nextMove = info.nextHand.currentMove
        move.firstMovePerformer = 0
        if move.prevMove != nil {
            move.firstMovePerformer = -1
        }
        if move.nextMove != nil {
            move.firstMovePerformer = 1
        }

        playerToMove = 0
        cardsLeft = 10 - game.deal.totalTaken
        maxDepth = 9 - game.deal.totalTaken
        if maxDepth > 4 {
            maxDepth = 2
        }

        cardMoves = []
    }
}
