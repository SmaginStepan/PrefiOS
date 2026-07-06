import Foundation

public final class AIInfo: Codable {

    public final class Take: Codable {
        public var takenBy: Int = 0
        public var firstMovePerformer: Int = 0
        public var prevMove: Card?
        public var myMove: Card?
        public var nextMove: Card?
        public var prikupMove: Card?

        public init() {}

        public func playColor() throws -> Int {
            switch firstMovePerformer {
            case 0:
                guard let move = myMove else { throw PrefError("Не определён заход!") }
                return move.coatColor
            case 1:
                guard let move = nextMove else { throw PrefError("Не определён заход!") }
                return move.coatColor
            case -1:
                guard let move = prevMove else { throw PrefError("Не определён заход!") }
                return move.coatColor
            default:
                throw PrefError("Не определён заход!")
            }
        }
    }

    public final class GameInfo: Codable {
        public var openedPrikup: Hand?
        public var discardedCards: Hand?
        public var gameType: GameType = .Raspasy
        public var contract: Int = 0
        public var contractor: Int = 0

        public init() {}
    }

    public final class HandInfo: Codable {
        public var isVister: Bool = false
        public var isContractor: Bool = false
        public var isMiserist: Bool = false
        public var isVisible: Bool = false
        public var visibleHand: Hand?
        public var colorNotExists: [Int] = []
        public var taken: Int = 0
        public var currentMove: Card?
        public var cardsCount: Int = 10

        public init() {}
    }

    public var firstMove: Int = 0

    public var myFirstMove: Bool {
        firstMove == 0
    }

    public var game: GameInfo = GameInfo()
    public var outOfPlay: [Take] = []
    public var outOfPlayByColor: OrderedIntDict<[Card]> = OrderedIntDict()
    public var myHand: HandInfo = HandInfo()
    public var prevHand: HandInfo = HandInfo()
    public var nextHand: HandInfo = HandInfo()
    public var currentPrikup: Card?
    public var knownPrikup: [Card] = []
    public var potentialDiscard: [PotentialDiscard]?

    public init() {}

    /// Rebuild transient per-suit indexes of nested hands after deserialization.
    public func restoreAfterLoad() {
        myHand.visibleHand?.sort()
        prevHand.visibleHand?.sort()
        nextHand.visibleHand?.sort()
        game.openedPrikup?.sort()
        game.discardedCards?.sort()
    }

    private func checkExists(_ player: Int, _ card: Card, _ trump: Int, _ playColor: Int, _ hand: HandInfo) {
        if card.coatColor == playColor {
            return
        }
        if card.coatColor == trump {
            if !hand.colorNotExists.contains(playColor) {
                hand.colorNotExists.append(playColor)
            }
        } else if trump >= 0 && trump <= 3 {
            if !hand.colorNotExists.contains(playColor) {
                hand.colorNotExists.append(playColor)
            }
            if !hand.colorNotExists.contains(trump) {
                hand.colorNotExists.append(trump)
            }
        } else {
            if !hand.colorNotExists.contains(playColor) {
                hand.colorNotExists.append(playColor)
            }
        }
    }

    private func addOutOfPlayByColor(_ card: Card) {
        var list = outOfPlayByColor[card.coatColor]!
        if list.first(where: { $0.coatColor == card.coatColor && $0.value == card.value }) == nil {
            list.append(card)
            outOfPlayByColor[card.coatColor] = list
        }
    }

    private func addKnownPrikup(_ prikupCard: Card) {
        if knownPrikup.first(where: { $0.coatColor == prikupCard.coatColor && $0.value == prikupCard.value }) == nil {
            knownPrikup.append(prikupCard)
        }
    }

    public func writeOutOfPlay(_ game: Game) throws {
        let myNum = game.playerInTurn
        let prevNum = game.getPrevPlayer()
        let nextNum = game.getNextPlayer()

        // Записываем все ранее вышедшие из игры карты
        outOfPlayByColor = OrderedIntDict()
        for i in 0..<4 {
            outOfPlayByColor[i] = []
        }
        for prikupCard in knownPrikup {
            addOutOfPlayByColor(prikupCard)
        }
        for take in outOfPlay {
            guard let prevMove = take.prevMove, let myMove = take.myMove, let nextMove = take.nextMove else {
                throw PrefError("Не определён заход!")
            }
            addOutOfPlayByColor(prevMove)
            addOutOfPlayByColor(myMove)
            addOutOfPlayByColor(nextMove)
            if let prikupMove = take.prikupMove {
                addOutOfPlayByColor(prikupMove)
            }
        }

        if game.phase == .EndTurn {
            // Конец хода: записываем взятку
            let take = Take()
            switch game.firstMovePerformer {
            case prevNum: take.firstMovePerformer = -1
            case myNum: take.firstMovePerformer = 0
            case nextNum: take.firstMovePerformer = 1
            default: break
            }

            take.prevMove = game.deal.inPlay[prevNum]
            take.myMove = game.deal.inPlay[myNum]
            take.nextMove = game.deal.inPlay[nextNum]
            switch game.playerToTake {
            case prevNum:
                take.takenBy = -1
                prevHand.taken += 1
            case myNum:
                take.takenBy = 0
                myHand.taken += 1
            case nextNum:
                take.takenBy = 1
                nextHand.taken += 1
            default: break
            }
            if game.deal.inPlay.containsKey(-1) {
                take.prikupMove = game.deal.inPlay[-1]
            }
            outOfPlay.append(take)

            firstMove = take.takenBy
        }

        // Записываем карты, находящиеся в игре
        prevHand.currentMove = game.deal.inPlay[prevNum]
        nextHand.currentMove = game.deal.inPlay[nextNum]
        currentPrikup = game.deal.inPlay[-1]

        if game.currentGameType != .Raspasy && game.contractor == game.playerInTurn && game.deal.totalTaken == 0 {
            // Мы знаем, что мы сбросили: записываем как вышедшие из игры карты и в известный прикуп
            var prikupCard = game.deal.prikup.cards[0]
            addKnownPrikup(prikupCard)
            addOutOfPlayByColor(prikupCard)
            prikupCard = game.deal.prikup.cards[1]
            addKnownPrikup(prikupCard)
            addOutOfPlayByColor(prikupCard)
        }

        for h in game.deal.inPlay.keys {
            // Записываем карты на столе как вышедшие и проверяем ренонс
            let card = game.deal.inPlay[h]!
            addOutOfPlayByColor(card)
            let hand: HandInfo
            switch h {
            case prevNum: hand = prevHand
            case myNum: hand = myHand
            case nextNum: hand = nextHand
            default: continue
            }
            checkExists(h, card, game.trump, game.deal.inPlayCoatColor, hand)
        }

        // Обновляем карты рук
        myHand.visibleHand = game.deal.hands[myNum].clone()
        myHand.isVisible = true
        myHand.currentMove = nil
        myHand.cardsCount = game.deal.hands[myNum].cards.count
        if game.deal.hands[nextNum].isVisible && game.isVister.containsKey(nextNum) {
            nextHand.isVisible = true
            nextHand.visibleHand = game.deal.hands[nextNum].clone()
        } else {
            nextHand.isVisible = false
            nextHand.visibleHand = nil
        }
        nextHand.cardsCount = game.deal.hands[nextNum].cards.count
        if game.deal.hands[prevNum].isVisible && game.isVister.containsKey(prevNum) {
            prevHand.isVisible = true
            prevHand.visibleHand = game.deal.hands[prevNum].clone()
        } else {
            prevHand.isVisible = false
            prevHand.visibleHand = nil
        }
        // NOTE: preserved from the original C# (it read hands[nextNum] here, not prevNum)
        prevHand.cardsCount = game.deal.hands[nextNum].cards.count

        // Зафиксировать распределение мастей
        var updated = true
        while updated {
            updated = false

            // Фиксируем, если карт масти не осталось в игре
            for i in 0..<4 {
                let inPlayCnt = 8 - myHand.visibleHand!.cardByCoat[i]!.count - outOfPlayByColor[i]!.count
                let prevNotExist = prevHand.colorNotExists.contains(i)
                let nextNotExist = nextHand.colorNotExists.contains(i)
                if inPlayCnt == 0 {
                    if !nextNotExist {
                        nextHand.colorNotExists.append(i)
                        if nextHand.colorNotExists.count == 4 && nextHand.cardsCount > 0 && !(nextHand.currentMove != nil && nextHand.cardsCount == 1) {
                            throw PrefError("Неверный расчёт вышедших взяток!")
                        }
                        updated = true
                    }
                    if !prevNotExist {
                        prevHand.colorNotExists.append(i)
                        if prevHand.colorNotExists.count == 4 && prevHand.cardsCount > 0 && !(prevHand.currentMove != nil && prevHand.cardsCount == 1) {
                            throw PrefError("Неверный расчёт вышедших взяток!")
                        }
                        updated = true
                    }
                    continue
                } else if inPlayCnt > 0 && prevNotExist && nextNotExist {
                    // Добавляем в известный прикуп, и в вышедшие из игры карты
                    for v in 7..<15 {
                        if myHand.visibleHand!.cardByCoat[i]!.first(where: { $0.value == v }) != nil {
                            continue
                        }
                        if outOfPlayByColor[i]!.first(where: { $0.value == v }) != nil {
                            continue
                        }
                        let card = Card(value: v, coatColor: i)
                        addKnownPrikup(card)
                        addOutOfPlayByColor(card)
                    }
                    updated = true
                }
            }

            // Фиксируем масти, строго разложившиеся по разным рукам
            var prevCnt = 0 // Кол-во карт, которые точно должны быть на пред. руке
            var nextCnt = 0 // Кол-во карт, которые точно должны быть на след. руке
            var nextMustHave: [Int] = [] // Масти, которые точно есть на след. руке
            var prevMustHave: [Int] = [] // Масти, которые точно есть на пред. руке
            for i in 0..<4 {
                let inPlayCnt = 8 - myHand.visibleHand!.cardByCoat[i]!.count - outOfPlayByColor[i]!.count
                let prevNotExist = prevHand.colorNotExists.contains(i)
                let nextNotExist = nextHand.colorNotExists.contains(i)
                if inPlayCnt > 0 && nextNotExist {
                    // Если карты есть в игре, но их нет на след. руке, значит все они на пред. руке!
                    prevCnt += inPlayCnt
                    prevMustHave.append(i)
                } else if inPlayCnt > 0 && prevNotExist {
                    // Если карты есть в игре, но их нет на пред. руке, значит все они на след. руке!
                    nextCnt += inPlayCnt
                    nextMustHave.append(i)
                }
            }
            let notKnown = game.deal.prikup.cards.count - knownPrikup.count
            if notKnown < 0 {
                throw PrefError("Нашелся прикуп (сброс), которого не было!")
            }

            prevCnt -= notKnown
            nextCnt -= notKnown

            let prevFull = prevHand.cardsCount <= prevCnt // Пред. рука полна: количество карт, которые точно есть на ней равно её длине
            let nextFull = nextHand.cardsCount <= nextCnt // След. рука полна: количество карт, которые точно есть на ней равно её длине
            for i in 0..<4 {
                let prevNotExist = prevHand.colorNotExists.contains(i)
                let nextNotExist = nextHand.colorNotExists.contains(i)
                if prevFull && !prevMustHave.contains(i) && !prevNotExist {
                    // На предыдущей только те карты, которых нет на след. руке
                    prevHand.colorNotExists.append(i)
                    if prevHand.colorNotExists.count == 4 && prevHand.cardsCount > 0 && !(prevHand.currentMove != nil && prevHand.cardsCount == 1) {
                        throw PrefError("Неверный расчёт вышедших взяток!")
                    }
                    updated = true
                }
                if nextFull && !nextMustHave.contains(i) && !nextNotExist {
                    // На следующей только те карты, которых нет на пред. руке
                    nextHand.colorNotExists.append(i)
                    if nextHand.colorNotExists.count == 4 && nextHand.cardsCount > 0 && !(nextHand.currentMove != nil && nextHand.cardsCount == 1) {
                        throw PrefError("Неверный расчёт вышедших взяток!")
                    }
                    updated = true
                }
            }
        }
    }

    public static func create(_ game: Game) {
        let ai = AIInfo()
        ai.game = GameInfo()
        ai.outOfPlay = []
        ai.outOfPlayByColor = OrderedIntDict()
        ai.myHand = HandInfo()
        ai.knownPrikup = []

        ai.myHand.visibleHand = game.deal.hands[game.playerInTurn].clone()
        ai.myHand.isVisible = true

        ai.nextHand = HandInfo()
        ai.prevHand = HandInfo()
        switch game.calc.dealer {
        case game.getPrevPlayer(): ai.firstMove = 0
        case game.playerInTurn: ai.firstMove = 1
        case game.getNextPlayer(): ai.firstMove = -1
        default: break
        }
        game.aIs[game.playerInTurn] = ai
    }
}
