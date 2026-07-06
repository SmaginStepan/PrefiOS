import Foundation

open class OpenPlay {

    public init() {}

    open func createExtremum(_ firstMovePerformer: Int, _ contractor: Int) throws -> Extremums {
        throw PrefError("abstract")
    }

    open func isMaximizing(_ player: Int, _ contractor: Int) -> Bool {
        false
    }

    open func createEstimation() -> Estimation {
        Estimation()
    }

    open func getPotentialDiscard(_ info: AIInfo) -> [PotentialDiscard]? {
        nil
    }

    public var iamSure = true

    private func getRaskladHash(_ rasklad: Rasklad, _ discard: PotentialDiscard, _ hand: Int) -> String {
        let cards = rasklad.getCardsInHand(hand, false).map { $0.id }.sorted()
        var id = discard.firstCard!.id
        while cards.contains(id) {
            id -= 1
        }
        var res = String(id)
        id = discard.secondCard!.id
        while cards.contains(id) {
            id -= 1
        }
        res += ":\(id)"
        return res
    }

    public func play(_ info: AIInfo, _ game: Game, _ allowedMoves: [Card]) throws -> Card? {
        if allowedMoves.count == 1 {
            // Думать нечего
            return allowedMoves[0]
        }
        let situation = GameSituation(game, info, self)
        let distinctMoves = try situation.getDistinctMoves()
        if distinctMoves.isEmpty {
            // Думать всё равно нечего...
            return allowedMoves[Int.random(in: 0..<allowedMoves.count)]
        }
        // Ухх... придётся таки думать...
        let contractHand = situation.contractor
        var contractHandLength = 10 - game.deal.totalTaken
        if game.deal.inPlay.containsKey(game.contractor) {
            contractHandLength -= 1
        }

        AiDebug.log("----------------------------------")
        AiDebug.log("CONTRACT = \(contractHand)")
        if AiDebug.enabled { Helper.logRasklad(situation.rasklad) }

        let potentialDiscard = info.potentialDiscard
        if let potentialDiscard = potentialDiscard, !potentialDiscard.isEmpty, situation.rasklad.getCardsInHand(contractHand, false).count > contractHandLength {
            // Перебираем сброс: ищем те варианты, которые ловятся
            var catched: [PotentialDiscard] = []
            var semanticProbability: [String: Double] = [:]
            var pSum = 0.0
            var pMax = 0.0
            for discard in situation.potentialDiscards! {
                discard.hash = getRaskladHash(situation.rasklad, discard, contractHand)
                let firstRemoved = try situation.rasklad.removeCard(discard.firstCard!, contractHand)
                let secondRemoved = try situation.rasklad.removeCard(discard.secondCard!, contractHand)

                guard let ewc = try situation.getEstimation(-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, true, true) else {
                    throw PrefError("Не удалось оценить сброс")
                }
                let est = ewc.estimation
                if est > 0 {
                    catched.append(discard)
                    pSum += discard.probability
                    if pMax < discard.probability {
                        pMax = discard.probability
                    }
                    let hash = discard.hash!
                    semanticProbability[hash] = (semanticProbability[hash] ?? 0.0) + discard.probability
                }

                if firstRemoved {
                    try situation.rasklad.addCard(discard.firstCard!, contractHand)
                }
                if secondRemoved {
                    try situation.rasklad.addCard(discard.secondCard!, contractHand)
                }
            }
            if catched.isEmpty {
                // Ничего не можем поймать :(
                AiDebug.log("----------------------------------")
                AiDebug.log("Ничего не можем поймать :(")
                return allowedMoves[Int.random(in: 0..<allowedMoves.count)]
            } else {
                // Исключаем маловероятные варианты
                let pMin = pMax / 5
                catched = catched.filter { $0.probability > pMin }
                // Проверяем, можем ли мы поймать гарантированно (при любом сносе из тех, что мы ловим)
                var removed: [Card] = []

                for discard in catched {
                    if try situation.rasklad.removeCard(discard.firstCard!, contractHand) {
                        removed.append(discard.firstCard!)
                    }
                    if try situation.rasklad.removeCard(discard.secondCard!, contractHand) {
                        removed.append(discard.secondCard!)
                    }
                }
                self.iamSure = true
                if !situation.rasklad.getCardsInHand(contractHand, false).isEmpty {
                    guard let all = try situation.getEstimation(-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, true, true) else {
                        throw PrefError("Не удалось оценить гарантированную ловлю")
                    }
                    for card in removed {
                        try situation.rasklad.addCard(card, contractHand)
                    }
                    if all.estimation > 0 {
                        AiDebug.log("----------------------------------")
                        AiDebug.log("Можем поймать при всех вариантах сноса :)")
                        if AiDebug.enabled { Helper.logRasklad(situation.rasklad) }
                        return all.bestCard
                    }
                }

                var cPos = 0.0
                pSum = catched.reduce(0.0) { $0 + $1.probability }
                let pos = Double.random(in: 0..<1) * pSum
                for discard in catched {
                    cPos += discard.probability
                    if pos <= cPos {
                        // Ловим данный расклад
                        let probability = semanticProbability[discard.hash!]! / pSum
                        self.iamSure = probability >= 0.45

                        let firstRemoved = try situation.rasklad.removeCard(discard.firstCard!, contractHand)
                        let secondRemoved = try situation.rasklad.removeCard(discard.secondCard!, contractHand)

                        let resOpt: EstimationWithCard?
                        if iamSure {
                            resOpt = try situation.getEstimation(-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, true, false)
                        } else {
                            resOpt = try situation.getEstimation(-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, true, true)
                        }
                        guard let res = resOpt else {
                            throw PrefError("Не удалось оценить ловлю расклада")
                        }

                        AiDebug.log("----------------------------------")
                        AiDebug.log("Ловим \(discard.firstCard!) \(discard.secondCard!) \(probability * 100.0)%")
                        AiDebug.log("EST = \(res.estimation)")
                        if AiDebug.enabled {
                            Helper.logRasklad(situation.rasklad)
                            Helper.logDiscards(catched)
                        }

                        if firstRemoved {
                            try situation.rasklad.addCard(discard.firstCard!, contractHand)
                        }
                        if secondRemoved {
                            try situation.rasklad.addCard(discard.secondCard!, contractHand)
                        }
                        return res.bestCard
                    }
                }
                throw PrefError("Неправильный расчёт вероятностей")
            }
        } else {
            self.iamSure = true
            situation.maxwidth = 0
            guard let res = try situation.getEstimation(-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, true, false, 1) else {
                throw PrefError("Не удалось оценить позицию")
            }
            AiDebug.log("----------------------------------")
            AiDebug.log("Знаем расклад")
            AiDebug.log("EST = \(res.estimation)")
            if AiDebug.enabled {
                Helper.logRasklad(situation.rasklad)
                AiDebug.log("calculated=\(situation.calculated)  skipped=\(situation.skipped)  maxwidth=\(situation.maxwidth)")
            }
            return res.bestCard
        }
    }
}
