import Foundation

public enum GamePhase: String, Codable {
    case NotStarted, Negotiations, VistNegotiations, PrikupOpened, Discarding, GameChoose, OpeningChoose, Playing, EndTurn, EndPlay, ScoreView, Ended
}

public final class Game: Codable {

    // MARK: - Данные

    public var deal: Deal = Deal()
    public var calc: Calculation = Calculation()
    public var phase: GamePhase = .NotStarted
    public var playerInTurn: Int = 0
    public var contractor: Int = 0
    public var contract: Int = 0
    public var trump: Int = 0
    public var currentGameType: GameType = .Raspasy
    public var isVister: OrderedIntDict<Bool> = OrderedIntDict()
    public var playersToWait: Int = 0

    public final class Bid: Codable {
        public var trump: Int = 0
        public var contract: Int = 0
        public var pas: Bool = false
        public var miser: Bool = false

        public init() {}

        // Note: display text; the SwiftUI layer localizes bids itself, this stays for logs.
        public var title: String {
            if pas {
                return "Пас"
            }
            if miser {
                return "Мизер!"
            }
            let trumpName: String
            switch trump {
            case 0: trumpName = "♠ пик"
            case 1: trumpName = "♣ треф"
            case 2: trumpName = "♦ бубей"
            case 3: trumpName = "♥ червей"
            default: trumpName = "без козыря"
            }
            return "\(contract) \(trumpName)"
        }
    }

    public var curentBids: OrderedIntDict<Bid> = OrderedIntDict()
    public var maxBid: Bid?
    public var aIs: OrderedIntDict<AIInfo> = OrderedIntDict()

    /// Replacement for the WP7 BackgroundWorker.ReportProgress: UI refresh signal. Transient.
    public var onProgress: (() -> Void)?

    public final class Animation {
        public var player: Int = 0
        public var card: Card?
        public var bid: Bid?
        public var text: String?

        public init() {}
    }

    /// Transient.
    public var animations: [Animation] = []

    private func addAnimation(_ animation: Animation) {
        animations.append(animation)
    }

    public var opening: Bool = false
    public var firstMovePerformer: Int = 0
    public var playerToTake: Int = 0

    private enum CodingKeys: String, CodingKey {
        case deal, calc, phase, playerInTurn, contractor, contract, trump, currentGameType,
             isVister, playersToWait, curentBids, maxBid, aIs, opening, firstMovePerformer, playerToTake
    }

    public init() {}

    // MARK: - Очерёдность игроков и определение ИИ

    // Передаём очерёдность хода следующему игроку
    public func getNextPlayer() -> Int {
        var player = playerInTurn
        player += 1
        if player >= 3 {
            player = 0
        }
        return player
    }

    public func getPrevPlayer() -> Int {
        var player = playerInTurn
        player -= 1
        if player < 0 {
            player = 2
        }
        return player
    }

    private func nextPlayer() {
        playerInTurn = getNextPlayer()
    }

    // Передаём очерёдность хода первому игроку (следующему за сдающим)
    private func firstPlayer() {
        playerInTurn = calc.dealer
        nextPlayer()
    }

    public func getFirstPlayer() -> Int {
        var num = calc.dealer
        num += 1
        if num >= calc.playersCount {
            num = 0
        }
        return num
    }

    public var isOpened: Bool {
        deal.hands.filter { $0.isVisible }.count > 1
    }

    // Является ли текущий игрок ИИ?
    // NOTE: returns false in several situations where the HUMAN plays cards from
    // AI hands (open whist play, catching a misère). Never call AI.makeMove blindly there.
    public func isAI() -> Bool {
        // TODO: Режим игры нескольких игроков
        let isOpened = self.isOpened
        let playerIsVister = contractor != 0 && isVister.containsKey(0) && isVister[0] == true
        let isVistPlaying = contractor != playerInTurn && phase == .Playing && currentGameType == .Normal
        if isVistPlaying && playerIsVister && isOpened {
            return false // Если игрок является вистующим или пасующим и играем в открытую, то он решает как ходить
        }
        if phase == .Playing && currentGameType == .Miser && contractor != 0 && playerInTurn != contractor {
            return false // Игрок всегда сам решает как ловить мизер
        }
        if playerInTurn > 0 {
            return true
        }
        if isVistPlaying && !playerIsVister && isOpened {
            return true // Если игрок спасовал, то он не ходит сам
        }
        return false
    }

    // MARK: - Начало игры

    /// Port of the C# Game() constructor (which read settings and created players).
    public static func create(ai1Name: String = "Первый", ai2Name: String = "Второй") -> Game {
        let game = Game()
        let settings = AppSettings()
        game.calc = Calculation(playersCount: 3, limit: settings.limit)
        game.calc.scores[0].name = settings.playerName
        game.calc.scores[1].name = ai1Name
        game.calc.scores[2].name = ai2Name
        game.calc.dealer = Int.random(in: 0..<3)
        game.aIs = OrderedIntDict()
        game.phase = .NotStarted
        return game
    }

    public static func load(_ name: String) throws -> Game? {
        guard let text = PrefStorage.readText(name) else { return nil }
        let game = try PrefStorage.decodeFromString(Game.self, text)
        game.deal.restoreAfterLoad()
        for info in game.aIs.values {
            info.restoreAfterLoad()
        }
        return game
    }

    public static func loadLast() -> Game? {
        (try? load("lastgame.json")) ?? nil
    }

    // Начало новой раздачи
    public func newDeal() throws {
        curentBids = OrderedIntDict()
        isVister = OrderedIntDict()
        deal = Deal()
        deal.hands[0].isVisible = true
        phase = .Negotiations
        maxBid = nil
        trump = -1
        // Создаём информацию для ИИ
        firstPlayer()
        for _ in 0..<3 {
            AIInfo.create(self)
            nextPlayer()
        }

        firstPlayer()
        onProgress?()
        try next()
    }

    // MARK: - Основной цикл

    public func next() throws {
        switch phase {
        case .NotStarted: try newDeal()
        case .Negotiations: try negotiationsNext()
        case .PrikupOpened: try prikupNext()
        case .Discarding: try discardingNext()
        case .GameChoose: try chooseNext()
        case .VistNegotiations: try vistNext()
        case .Playing: try playNext()
        case .EndPlay: try endNext()
        case .ScoreView: try scoreNext()
        case .EndTurn: try turnNext()
        case .OpeningChoose: try openingChooseNext()
        case .Ended: break
        }
    }

    // MARK: - Загрузка и сохранение

    public func save(_ name: String) {
        PrefStorage.deleteFamily(name)
        PrefStorage.writeText(name, PrefStorage.encodeToString(self))
    }

    public func saveLast() {
        save("lastgame.json")
    }

    // MARK: - Торговля

    private func incBid(_ bid: Bid) -> Bid? {
        let res = Bid()
        res.contract = bid.contract
        res.trump = bid.trump + 1
        if res.trump > 4 {
            res.trump = 0
            res.contract += 1
        }
        if res.contract > 10 {
            return nil
        }
        return res
    }

    // Возвращаем все допустимые варианты объявления игры
    public func getAllowedBids() -> [Bid] {
        var list: [Bid] = []
        var curBid: Bid?
        if let maxBid = maxBid {
            if maxBid.miser {
                let b = Bid()
                b.contract = 9
                b.trump = 0
                curBid = b
            } else {
                curBid = maxBid
                if phase == .Negotiations {
                    var prevBid: Bid?
                    if curentBids.containsKey(getPrevPlayer()) {
                        prevBid = curentBids[getPrevPlayer()]
                    }
                    if prevBid == nil || !prevBid!.pas {
                        curBid = incBid(curBid!)
                    }
                }
            }
        } else {
            let b = Bid()
            b.contract = calc.currentRaspasyExit
            b.trump = 0
            curBid = b
        }
        if phase == .Negotiations {
            let b = Bid()
            b.pas = true
            list.append(b)
        }
        if let cur = curBid, cur.contract < 9, !curentBids.containsKey(playerInTurn) {
            let b = Bid()
            b.miser = true
            list.append(b)
        }
        while let cur = curBid {
            list.append(cur)
            curBid = incBid(cur)
        }
        return list
    }

    // Действие торговли
    // Если объявляется игра, которая недопустима по правилам, то возвращается false
    @discardableResult
    public func makeBid(_ bid: Bid) -> Bool {
        let player = playerInTurn
        // Проверяем, можно ли объявить такую игру по правилам
        if !bid.pas {
            maxBid = bid
            contractor = player
        }

        let animation = Animation()
        animation.player = playerInTurn
        animation.bid = bid
        addAnimation(animation)

        curentBids[player] = bid

        nextPlayer()
        return true
    }

    // Проверка окончания торгов
    private func negitiationsEnded() throws -> Bool {
        var cntPas = 0
        for cbid in curentBids.values where cbid.pas {
            cntPas += 1
        }
        if cntPas == 2 && curentBids.count == 3 {
            if maxBid!.miser {
                // Начинаем мизер
                currentGameType = .Miser
                isVister.removeAll()
                isVister[getNextPlayer()] = false
                isVister[getPrevPlayer()] = false
                opening = true
                // Contractor уже установлен
                phase = .PrikupOpened
                playersToWait = 3
                try next()
            } else {
                // Начинаем игру
                opening = false
                currentGameType = .Normal
                phase = .PrikupOpened
                playersToWait = 3
                try next()
            }
        } else if cntPas == 3 {
            // Начинаем распасы
            currentGameType = .Raspasy
            trump = -1
            phase = .Playing
            firstMovePerformer = -1
            opening = false
            raspasyPrikup()
            try next()
        } else {
            return false
        }
        return true
    }

    private func negotiationsNext() throws {
        // Проверяем, окончены ли торги?
        if try !negitiationsEnded() {
            // Торги не окончены
            if curentBids.containsKey(playerInTurn) && curentBids[playerInTurn]!.pas {
                // Игрок уже спасовал
                nextPlayer()
                try next()
                return
            }
            if isAI() {
                try AI.makeMove(self)
            } else {
                // Ждём ответа игрока
            }
        }
    }

    // MARK: - Открытие прикупа

    /// Игрок посмотрел прикуп
    public func prikupClose() {
        playersToWait -= 1
        nextPlayer()
    }

    public func prikupNext() throws {
        deal.prikup.isVisible = true
        if playersToWait == 0 {
            // Все посмотрели прикуп
            deal.prikup.isVisible = false
            playerInTurn = contractor
            for card in deal.prikup.cards {
                deal.hands[playerInTurn].cards.append(card)
            }
            deal.prikup.cards.removeAll()
            deal.hands[playerInTurn].sort()
            phase = .Discarding

            try next()
        } else if isAI() {
            try AI.makeMove(self)
        } else {
            // Ждём ответа игрока
        }
    }

    // MARK: - Сброс лишних карт

    public func discardCard(_ card: Card) {
        let cards = deal.hands[playerInTurn].cards
        var pos = -1
        for i in cards.indices {
            if cards[i].coatColor == card.coatColor && cards[i].value == card.value {
                pos = i
            }
        }
        if pos >= 0 {
            deal.prikup.cards.append(card)
            deal.prikup.sort()
            deal.hands[playerInTurn].cards.remove(at: pos)
            deal.hands[playerInTurn].sort()
        }
    }

    public func discardingNext() throws {
        if deal.hands[playerInTurn].cards.count == 12 {
            let ai = aIs[playerInTurn]!
            let disc = try Helper.getPotentialDiscards(ai, self)
            for ainfo in aIs.values {
                ainfo.potentialDiscard = disc
            }
        }
        if deal.hands[playerInTurn].cards.count > 10 {
            if isAI() {
                try AI.makeMove(self)
            } else {
                // Ждём игрока
            }
        } else {
            onProgress?()
            if currentGameType != .Miser {
                // переходим к фазе объявления игры
                phase = .GameChoose
                playerInTurn = contractor
                try next()
            } else {
                // Мизер: играем
                phase = .Playing
                firstMovePerformer = -1
                opening = true
                firstPlayer()
                try next()
            }
        }
    }

    // MARK: - Объявление игры

    /// Игрок объявляет игру
    public func setContract(_ contract: Bid) {
        let animation = Animation()
        animation.player = playerInTurn
        animation.bid = contract
        addAnimation(animation)
        self.contract = contract.contract
        trump = contract.trump
        maxBid = contract
        isVister.removeAll()
        // Переходим к объявлению вистующих
        phase = .VistNegotiations
        nextPlayer()
        if calc.rules.stalindgrad && contract.contract == 6 && contract.trump == 0 {
            // Сталинград: все вистуют
            for i in 0..<3 where i != contractor {
                isVister[i] = true
            }
            phase = .Playing
            firstMovePerformer = -1
            firstPlayer()
        }
    }

    public func chooseNext() throws {
        if isAI() {
            try AI.makeMove(self)
        } else {
            // Ждём действий игрока
        }
    }

    // MARK: - Определение вистующих

    // Действие определения вистующих
    public func setVist(_ isVist: Bool) {
        let player = playerInTurn
        let animation = Animation()
        animation.player = playerInTurn
        animation.text = isVist ? "Вист!" : "Пас"
        addAnimation(animation)
        isVister[player] = isVist
        nextPlayer()
    }

    private func vistEnded() -> Bool {
        if isVister.count == 2 {
            if isVister.values.filter({ $0 }).count == 0 && getPrevPlayer() == contractor {
                // Если никто не вистовал, даём ещё один шанс первому вистующему:
                return false
            }
            return true
        }
        return false
    }

    private func vistNext() throws {
        if playerInTurn == contractor {
            nextPlayer()
        }
        // Определяем, что висты закончены
        if !vistEnded() {
            // Висты не окончены
            if isAI() {
                try AI.makeMove(self)
            } else {
                // Ждём ответа игрока
            }
        } else {
            let vistersCount = isVister.values.filter { $0 }.count
            if vistersCount == 0 {
                // Сразу записываем результат
                deal.hands[contractor].taken = contract
                // Полвиста:
                if contract < 8 {
                    let gr = Calculation.GameResult()
                    gr.contract = contract
                    deal.hands[playerInTurn].taken = gr.singleVistNeeded
                }
                writeGameResult()
                try next()
            } else if vistersCount == 1 {
                // Определяем, как будем играть: в открытую или в закрытую
                phase = .OpeningChoose
                playerInTurn = isVister.entries.first { $0.value }!.key
                try next()
            } else {
                // Играем
                phase = .Playing
                firstMovePerformer = -1
                firstPlayer()
                try next()
            }
        }
    }

    // MARK: - Определение режима вистования (в открытую\в закрытую)

    public func setOpeningChoice(_ open: Bool) {
        let animation = Animation()
        animation.player = playerInTurn
        animation.text = open ? "В открытую!" : "В закрытую"
        addAnimation(animation)
        opening = open
        phase = .Playing
        firstMovePerformer = -1
        firstPlayer()
    }

    private func openingChooseNext() throws {
        if isAI() {
            try AI.makeMove(self)
        } else {
            // Ждём игрока
        }
    }

    // MARK: - Игра

    public func getAllowedMoves() -> [Card] {
        var list: [Card] = []
        for card in deal.hands[playerInTurn].cards {
            if playCard(card, onlyCheck: true) {
                list.append(card)
            }
        }
        return list
    }

    // Действие игры: возвращает false, если действие недопустимо
    @discardableResult
    public func playCard(_ card: Card, onlyCheck: Bool = false) -> Bool {
        let player = playerInTurn
        let hand = deal.hands[player]
        if !onlyCheck && firstMovePerformer < 0 {
            firstMovePerformer = player
        }
        for c in hand.cards {
            if c.coatColor == card.coatColor && c.value == card.value {
                if deal.inPlay.isEmpty {
                    deal.inPlayCoatColor = card.coatColor
                }
                let hasColor = hand.hasCoatColor(deal.inPlayCoatColor)
                let hasTrump = hand.hasCoatColor(trump)
                if hasColor && deal.inPlayCoatColor != card.coatColor {
                    // Нельзя класть карту не в масть, если есть карта в масть
                    return false
                }
                if !hasColor && hasTrump && card.coatColor != trump {
                    // Нельзя класть не козыря, если есть козырь
                    return false
                }
                if !onlyCheck {
                    if isAI() {
                        let animation = Animation()
                        animation.player = playerInTurn
                        animation.card = card
                        addAnimation(animation)
                    }

                    deal.hands[player].cards.removeAll { $0 === c }
                    deal.hands[player].sort()
                    deal.inPlay[player] = card
                    nextPlayer()
                }

                return true
            }
        }
        return false
    }

    private func writeGameResult() {
        phase = .EndPlay
        playersToWait = 3
    }

    private func playNext() throws {
        // Открываем карты
        if deal.totalTaken == 0 && opening && playerInTurn != contractor {
            for i in 0..<calc.playersCount where i != contractor {
                deal.hands[i].isVisible = true
            }
        }

        let isPrik4 = isTurnWithPrikup()
        if deal.totalTaken == 10 {
            // Игра закончена
            writeGameResult()

            try next()
        } else if (isPrik4 && deal.inPlay.count == 4) || (!isPrik4 && deal.inPlay.count == 3) {
            // Розыгрыш закончен
            phase = .EndTurn
            playersToWait = 3
            // Берёт игрок со старшей картой
            var maxCard: Card?
            var maxPlayer = -1
            for player in deal.inPlay.keys {
                if player < 0 || player > 2 {
                    continue
                }
                let card = deal.inPlay[player]!

                if maxCard == nil || card.greaterThan(maxCard!, trump: trump, initColor: deal.inPlayCoatColor) {
                    maxPlayer = player
                    maxCard = card
                }
            }
            playerToTake = maxPlayer
            try next()
        } else if isAI() {
            try AI.makeMove(self)
        } else {
            let info = aIs[playerInTurn]!
            try info.writeOutOfPlay(self)
            // Ждём игрока
        }
    }

    // MARK: - Просмотр взятки

    /// Игрок посмотрел взятку
    public func turnClose() {
        playersToWait -= 1
        nextPlayer()
    }

    private func turnNext() throws {
        if playersToWait == 0 {
            // Все посмотрели результат
            phase = .Playing
            firstMovePerformer = -1
            // Берёт игрок со старшей картой...

            deal.inPlay.removeAll()
            deal.hands[playerToTake].taken += 1
            playerInTurn = playerToTake
            raspasyPrikup()
            try next()
        } else {
            let info = aIs[playerInTurn]!
            try info.writeOutOfPlay(self)
            if isAI() {
                try AI.makeMove(self)
            } else {
                // Ждём игрока
            }
        }
    }

    private func isTurnWithPrikup() -> Bool {
        currentGameType == .Raspasy && calc.rules.gameType != .Rostov && deal.totalTaken < 2
    }

    private func raspasyPrikup() {
        if isTurnWithPrikup() {
            // Открываем масть из прикупа
            let animation = Animation()
            animation.player = -1
            animation.card = deal.prikup.cards[0]
            addAnimation(animation)
            deal.inPlayCoatColor = deal.prikup.cards[0].coatColor
            deal.inPlay[-1] = deal.prikup.cards[0]
            deal.prikup.cards.remove(at: 0)
            firstPlayer()
        }
    }

    // MARK: - Конец розыгрыша

    /// Игрок посмотрел результат игры
    public func endConfirm() {
        playersToWait -= 1
        nextPlayer()
    }

    public func getGameResult() -> Calculation.GameResult {
        let result = Calculation.GameResult()
        result.gameType = currentGameType
        result.contract = contract
        result.contractor = contractor
        result.dealer = calc.dealer
        result.multiplier = calc.currentRaspasyMultiplier
        result.visters = isVister.entries.filter { $0.value }.map { $0.key }
        result.taken = OrderedIntDict()
        for i in 0..<3 {
            let hand = deal.hands[i]
            result.taken[i] = hand.taken
        }
        return result
    }

    private func endNext() throws {
        if playersToWait == 0 {
            // Все посмотрели счёт
            let result = getGameResult()
            calc.writeGame(result)
            phase = .ScoreView
            playersToWait = 3
            try next()
        } else if isAI() {
            try AI.makeMove(self)
        } else {
            // Ждём игрока
        }
    }

    // MARK: - Просмотр результата

    /// Игрок посмотрел результат игры
    public func scoreClose() {
        playersToWait -= 1
        nextPlayer()
    }

    private func scoreNext() throws {
        if playersToWait == 0 {
            // Все посмотрели счёт
            if !calc.isFinished {
                // Новый розыгрыш
                try newDeal()
            } else {
                // Игра окончена!
                phase = .Ended
            }
        } else if isAI() {
            try AI.makeMove(self)
        } else {
            // Ждём игрока
        }
    }
}

extension Game.Bid: CustomStringConvertible {
    public var description: String { title }
}
