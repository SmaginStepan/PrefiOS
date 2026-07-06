import Foundation

public enum AI {

    public static func makeMove(_ game: Game) throws {
        let info: AIInfo
        switch game.phase {
        case .Discarding:
            info = game.aIs[game.playerInTurn]!
            info.myHand.visibleHand = game.deal.hands[game.playerInTurn]

            let discardingCards = try getDiscard(info, game)
            game.discardCard(discardingCards.0)
            game.discardCard(discardingCards.1)

            try game.next()
        case .Ended:
            // Невозможно!!!
            break
        case .EndPlay:
            game.endConfirm()
            try game.next()
        case .EndTurn:
            game.turnClose()
            try game.next()
        case .GameChoose:
            info = game.aIs[game.playerInTurn]!
            info.myHand.visibleHand = game.deal.hands[game.playerInTurn]
            let bbid = try getContract(info, game.getAllowedBids())
            game.setContract(bbid)
            try game.next()
        case .Negotiations:
            let bid = getBid(game.aIs[game.playerInTurn]!, game.getAllowedBids())
            game.makeBid(bid)
            try game.next()
        case .NotStarted:
            // Невозможно!!!
            break
        case .OpeningChoose:
            if Int.random(in: 0..<10) < 9 {
                game.setOpeningChoice(true)
            } else {
                game.setOpeningChoice(false)
            }
            try game.next()
        case .Playing:
            info = game.aIs[game.playerInTurn]!
            try info.writeOutOfPlay(game)
            guard let cardToPlay = try playCard(info, game) else {
                throw PrefError("ИИ не выбрал карту!")
            }
            info.myHand.visibleHand!.cards = info.myHand.visibleHand!.cards
                .filter { $0.coatColor != cardToPlay.coatColor || $0.value != cardToPlay.value }
            info.myHand.visibleHand!.sort()
            game.playCard(cardToPlay)
            try game.next()
        case .PrikupOpened:
            game.prikupClose()
            try game.next()
        case .ScoreView:
            game.scoreClose()
            try game.next()
        case .VistNegotiations:
            // Всегда предлагаем вистануть другому
            if game.isVister.isEmpty || game.isVister.values.first! {
                game.setVist(false)
            } else {
                // TODO: Проверить, стоит ли вистовать?
                game.setVist(true)
            }
            try game.next()
        }
    }

    public static func getDiscard(_ info: AIInfo, _ game: Game) throws -> (Card, Card) {
        if game.currentGameType == .Miser {
            return try getCardsForMiserDiscard(info, game)
        } else {
            return try getBestCardsForNormalDiscard(info, game.getAllowedBids())
        }
    }

    public static func playCard(_ info: AIInfo, _ game: Game) throws -> Card? {
        let allowedMoves = game.getAllowedMoves()
        let cardToPlay: Card?
        switch game.currentGameType {
        case .Raspasy:
            cardToPlay = try RaspasyHidden().play(info, game, allowedMoves)
        case .Normal:
            if game.playerInTurn != game.contractor {
                if game.isOpened {
                    cardToPlay = try VistyOpen().play(info, game, allowedMoves)
                } else {
                    cardToPlay = try VistyHidden().play(info, game, allowedMoves)
                }
            } else {
                if game.isOpened {
                    cardToPlay = try ContractOpen().play(info, game, allowedMoves)
                } else {
                    cardToPlay = try ContractHidden().play(info, game, allowedMoves)
                }
            }
        case .Miser:
            if game.playerInTurn != game.contractor {
                if game.isOpened {
                    cardToPlay = try MiserAntiOpen().play(info, game, allowedMoves)
                } else {
                    throw PrefError("НОНСЕНС!!!")
                }
            } else {
                if game.isOpened {
                    cardToPlay = try MiserOpen().play(info, game, allowedMoves)
                } else {
                    cardToPlay = try MiserHidden().play(info, game, allowedMoves)
                }
            }
        default:
            cardToPlay = allowedMoves[Int.random(in: 0..<allowedMoves.count)]
        }
        return cardToPlay
    }

    private static func getBestCardsForNormalDiscard(_ info: AIInfo, _ bidsIn: [Game.Bid]) throws -> (Card, Card) {
        let bids = Array(bidsIn.drop(while: { $0.pas || $0.miser }).prefix(5))
        let hand = info.myHand.visibleHand!.clone()
        var max = -Double.greatestFiniteMagnitude
        var list: [(Card, Card)] = []
        for i in 0..<4 {
            var cards: [Card] = hand.cardByCoat[i]!.sorted { $0.value < $1.value }
            guard let firstCard = cards.first else { continue }
            for j in i..<4 {
                cards = hand.cardByCoat[j]!.sorted { $0.value < $1.value }
                if i == j {
                    cards = Array(cards.dropFirst(1))
                }
                guard let secondCard = cards.first else { continue }

                info.myHand.visibleHand = hand.clone()
                for card in info.myHand.visibleHand!.cards {
                    if (card.value == firstCard.value && card.coatColor == firstCard.coatColor)
                        || (card.value == secondCard.value && card.coatColor == secondCard.coatColor) {
                        info.myHand.visibleHand!.cards.removeAll { $0 === card }
                    }
                }
                info.myHand.visibleHand!.sort()

                let nt = NormalTakes(info)

                for bid in bids {
                    let cnt = nt.getMaxContract(bid.trump, info.myHand.visibleHand!, info.myFirstMove, true)
                    let v = (cnt.takes - Double(bid.contract)) * 10000 + cnt.turns
                    if v > max {
                        max = v
                        list.removeAll()
                        list.append((firstCard, secondCard))
                    }
                }
            }
        }
        info.myHand.visibleHand = hand
        guard !list.isEmpty else {
            throw PrefError("Не найден сброс!")
        }
        return list[Int.random(in: 0..<list.count)]
    }

    private static func getCardsForMiserDiscard(_ info: AIInfo, _ game: Game) throws -> (Card, Card) {
        guard let list = try Helper.getPotentialDiscards(info, game) else {
            throw PrefError("Неверный рассчёт вероятностей")
        }
        let pSum = list.reduce(0.0) { $0 + $1.probability }
        let pos = Double.random(in: 0..<1) * pSum
        var cPos = 0.0
        for discard in list {
            cPos += discard.probability
            if pos < cPos {
                return (discard.firstCard!, discard.secondCard!)
            }
        }

        throw PrefError("Неверный рассчёт вероятностей")
    }

    public static func getBid(_ info: AIInfo, _ bidsIn: [Game.Bid]) -> Game.Bid {
        let nt = NormalTakes(info)
        let pas = Game.Bid()
        pas.pas = true
        if bidsIn.first(where: { $0.miser }) != nil {
            // Мы можем объявить мизер
            let mt = MiserTakes(info)
            if mt.totalTakes <= 1.5 {
                let b = Game.Bid()
                b.miser = true
                return b
            }
        }
        let bids = Array(bidsIn.drop(while: { $0.pas || $0.miser }).prefix(5))
        if bids.isEmpty {
            return pas
        }
        for bid in bids {
            if Double(nt.getMaxContract(bid.trump, info.myHand.visibleHand!, info.myFirstMove, false).maxContract) >= Double(bid.contract) {
                return bids.first!
            }
        }
        return pas
    }

    public static func getContract(_ info: AIInfo, _ bidsIn: [Game.Bid]) throws -> Game.Bid {
        let nt = NormalTakes(info)
        let bids = Array(bidsIn.drop(while: { $0.pas || $0.miser }).prefix(5))
        if bids.isEmpty {
            throw PrefError("Нет доступного контракта!")
        }
        var max = -Double.greatestFiniteMagnitude
        var bestBid: Game.Bid?
        for bid in bids {
            let cnt = nt.getMaxContract(bid.trump, info.myHand.visibleHand!, info.myFirstMove, false)
            var v = cnt.takes * 10000 + cnt.turns
            if cnt.takes >= Double(bid.contract) {
                v += 100000
            }
            if v > max {
                max = v
                bestBid = bid
                if cnt.takes > Double(bestBid!.contract) {
                    bestBid!.contract = Int(cnt.takes.rounded(.down))
                }
            }
        }

        return bestBid!
    }
}
