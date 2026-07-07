import Foundation
import SwiftUI
// The engine is deliberately non-Sendable: all engine work is confined to the
// view model's serial gameQueue, matching the original app's BackgroundWorker.
@preconcurrency import PrefEngine

// TableInfo now lives in PrefEngine (it is also the multiplayer wire shape).

struct CardAnim {
    let card: Card
    let fromX: Double
    let fromY: Double
    let toX: Double
    let toY: Double
}

struct TrickAnim {
    let cards: [PlacedCard]
    let toX: Double
    let toY: Double
}

struct SayEvent {
    let player: Int
    let bid: Game.Bid?
    let text: String?
}

@MainActor
final class GameViewModel: ObservableObject {

    private(set) var game: Game!
    private weak var app: AppState?

    /// Engine work runs off the main thread on this serial queue.
    private let gameQueue = DispatchQueue(label: "pref.game", qos: .userInitiated)

    @Published private(set) var field: [PlacedCard] = []
    @Published private(set) var pinnedOverlays: [PlacedCard] = []
    @Published private(set) var info = TableInfo()

    @Published private(set) var thinking = false
    @Published private(set) var busy = false

    @Published private(set) var cardAnim: CardAnim?
    @Published private(set) var trickAnim: TrickAnim?
    @Published private(set) var animProgress: Double = 0

    /// Drives animation progress 0→1 manually with a simple time loop, so the
    /// card flight does not depend on any UI animation context.
    private func runAnim(durationMs: Double = 360) async {
        let start = Date()
        animProgress = 0
        while true {
            let t = -start.timeIntervalSinceNow * 1000.0 / durationMs
            if t >= 1 { break }
            animProgress = t
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
        animProgress = 1
    }

    @Published private(set) var say: SayEvent?

    @Published private(set) var menuBids: [Game.Bid] = []
    @Published var selectedBid: Game.Bid?
    @Published var cardsToDiscard: [Card] = []

    @Published var transientHint: String?
    @Published var showTricks = false
    @Published private(set) var tricks: [AIInfo.Take] = []
    @Published private(set) var tricksNames: [Int: String] = [:]
    private var showPrikupHand: Int?

    var onShowScore: (() -> Void)?

    private var started = false
    private var loopRunning = false

    // hosted multiplayer: the session (not this VM) drives the loop
    private(set) var hosted = false
    @Published private(set) var scoresOverlay: ScoreSnap?
    private(set) var session: HostGameSession?

    /// Invoked after the host saves-and-finishes (e.g. to leave the room).
    var onMatchFinished: (() -> Void)?

    /// 4-player sessions swap in a fresh 3-player game every deal.
    @discardableResult
    private func syncHostedGame() -> Bool {
        guard let s = session else { return false }
        if game === s.game { return false }
        game = s.game
        refresh()
        return true
    }

    /// Save the running multiplayer standings as a regular pulka file.
    func saveScoreSheet() -> Bool {
        (session?.matchCalc ?? game.calc).save()
        return true
    }

    /// Host only: save the pulka and end the multiplayer match for everyone.
    func saveAndFinish() {
        guard let s = session, !busy else { return }
        Task {
            busy = true
            _ = saveScoreSheet()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                gameQueue.async {
                    s.abortMatch()
                    continuation.resume()
                }
            }
            busy = false
            syncHostedGame()
            buildMenu()
            refresh()
            onMatchFinished?()
        }
    }

    /// A guest reconnected: push everyone a fresh snapshot.
    func onGuestReconnected() {
        guard let s = session else { return }
        gameQueue.async {
            s.rebroadcast()
        }
    }

    /// Host side of a multiplayer game. Seat 0 is the local player.
    /// Hosted games never touch the single-player save.
    func startHosted(
        names: [String],
        seatKinds: [SeatKind],
        sendToSeat: @escaping (Int, GameMsg.State) -> Void,
        initialCalc: Calculation? = nil,
        rules: GameRules? = nil,
        limit: Int? = nil
    ) {
        if started { return }
        started = true
        hosted = true
        let n = seatKinds.count
        // resume a saved pulka (its columns seated to match the room players),
        // or a fresh sheet with the room's rules
        let matchCalc: Calculation
        if let initialCalc = initialCalc {
            matchCalc = initialCalc.reordered(Calculation.seatOrder(names, initialCalc))
        } else {
            matchCalc = Calculation(playersCount: n, limit: limit ?? 10)
            if let rules = rules {
                matchCalc.rules = rules.clone()
            }
        }
        for (i, name) in names.prefix(n).enumerated() {
            matchCalc.scores[i].name = name
        }
        let s = HostGameSession(
            seats: seatKinds,
            names: names,
            matchCalc: matchCalc,
            sendToSeat: sendToSeat,
            onLocalTurn: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.syncHostedGame()
                    self?.buildMenu()
                    self?.refresh()
                }
            }
        )
        session = s
        game = s.game
        busy = true
        thinking = true
        Task {
            let anims: [Game.Animation] = await withCheckedContinuation { continuation in
                gameQueue.async {
                    do {
                        try s.start()
                    } catch {
                        NSLog("Pref: hosted start error: %@", "\(error)")
                    }
                    continuation.resume(returning: s.drainAnims())
                }
            }
            thinking = false
            syncHostedGame()
            await processAnimations(queue: anims)
            busy = false
            buildMenu()
            refresh()
        }
    }

    /// A remote player's action arrived over the relay.
    func onRemoteAct(_ seat: Int, _ act: GameMsg.Act) {
        guard let s = session else { return }
        Task {
            let anims: [Game.Animation] = await withCheckedContinuation { continuation in
                gameQueue.async {
                    do {
                        try s.onRemoteAct(seat, act)
                    } catch {
                        NSLog("Pref: remote act error: %@", "\(error)")
                    }
                    continuation.resume(returning: s.drainAnims())
                }
            }
            syncHostedGame()
            if !anims.isEmpty {
                busy = true
                await processAnimations(queue: anims)
                busy = false
            }
            buildMenu()
            refresh()
        }
    }

    func start(app: AppState, ai1Name: String, ai2Name: String) {
        self.app = app
        if !started {
            if let existing = app.game {
                game = existing
            } else {
                game = Game.create(ai1Name: ai1Name, ai2Name: ai2Name)
            }
            app.game = game
            started = true
            refresh()
        }
        // The original page always kicked the game loop on navigation (including
        // returning from the score sheet).
        gameNext()
    }

    private func buildTableInfo() -> TableInfo {
        var info = TableInfo()
        info.phase = game.phase
        info.names = game.calc.scores.map { $0.name }
        info.dealer = game.calc.dealer
        info.taken = game.deal.hands.map { $0.taken }
        info.currentGameType = game.currentGameType
        info.contractor = game.contractor
        info.isVister = game.isVister
        info.curentBids = game.curentBids
        info.maxBid = game.maxBid
        info.playerToTake = game.playerToTake
        info.playerInTurn = game.playerInTurn
        info.controller = game.turnController()
        info.watching = session?.hostActive == false
        info.sitOutName = session?.sitOutName
        info.gameResult = game.phase == .EndPlay ? game.getGameResult() : nil
        info.showPrikupBtn1 = (game.phase == .Playing || game.phase == .EndTurn)
            && (game.currentGameType == .Normal || game.currentGameType == .Miser)
            && game.contractor == 1 && game.opening && showPrikupHand != 1
        info.showPrikupBtn2 = (game.phase == .Playing || game.phase == .EndTurn)
            && (game.currentGameType == .Normal || game.currentGameType == .Miser)
            && game.contractor == 2 && game.opening && showPrikupHand != 2
        info.showPrikupHideBtn = (game.phase == .Playing || game.phase == .EndTurn)
            && showPrikupHand != nil && showPrikupHand == game.contractor
        info.showTricksBtn = game.phase == .Playing || game.phase == .EndTurn
            || game.phase == .EndPlay
        return info
    }

    // The engine keeps a finished trick in deal.inPlay until every player has
    // confirmed it; once the local player confirmed, keep it off the table so
    // it doesn't reappear while the remote players are still looking. Tied to
    // the trick number: when the host only watches, whole tricks can pass
    // between two refreshes without the phase ever leaving EndTurn.
    private var trickCollected = false
    private var trickCollectedAt = -1

    /// Recompute all published render state from the (quiescent) game.
    private func refresh() {
        showPrikupHand = nil
        if game.phase != .EndTurn || game.deal.totalTaken != trickCollectedAt {
            trickCollected = false
        }
        let s = session
        let f: [PlacedCard]
        if let s = s, !s.hostActive {
            f = RemoteViews.buildFieldFor(game, 0, spectator: true) // host deals: watch only
        } else {
            f = TableLayout.computeField(game, discardSelection: cardsToDiscard)
        }
        field = trickCollected ? f.filter { !$0.isInPlay } : f
        pinnedOverlays.removeAll()
        info = buildTableInfo()
        scoresOverlay = (hosted && s != nil && (game.phase == .ScoreView || game.phase == .Ended))
            ? RemoteViews.buildScoresFrom(s!.matchCalc, 0)
            : nil
    }

    func gameNext() {
        if loopRunning { return }
        if hosted, let s = session {
            // hosted: the local action was already applied; the session runs
            // next() + bots + remote broadcasting
            game.animations.removeAll() // the own action was animated by the UI already
            loopRunning = true
            busy = true
            thinking = true
            transientHint = nil
            Task {
                let anims: [Game.Animation] = await withCheckedContinuation { continuation in
                    gameQueue.async { [game = self.game!] in
                        do {
                            try s.onLocalActed()
                        } catch {
                            NSLog("Pref: hosted loop error (phase=%@): %@", game.phase.rawValue, "\(error)")
                        }
                        continuation.resume(returning: s.drainAnims())
                    }
                }
                thinking = false
                syncHostedGame()
                await processAnimations(queue: anims)
                busy = false
                buildMenu()
                refresh()
                loopRunning = false
            }
            return
        }
        loopRunning = true
        busy = true
        thinking = true
        transientHint = nil
        let game = self.game!
        Task {
            let error: Error? = await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
                gameQueue.async { [weak self] in
                    game.onProgress = {
                        // Called from the game loop at safe points; compute on this
                        // thread while state is consistent, publish on main.
                        let f = TableLayout.computeField(game)
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.field = f
                            self.pinnedOverlays.removeAll()
                            self.info = self.buildTableInfo()
                        }
                    }
                    _ = self
                    do {
                        try game.next()
                        continuation.resume(returning: nil)
                    } catch {
                        // The original WP7 app swallowed engine/AI exceptions inside its
                        // BackgroundWorker; do the same but log them for diagnosis.
                        NSLog("Pref: game loop error (phase=%@, player=%d): %@",
                              game.phase.rawValue, game.playerInTurn, "\(error)")
                        continuation.resume(returning: error)
                    }
                }
            }
            thinking = false
            if let error = error {
                transientHint = "\(error)"
            }
            await processAnimations()
            busy = false
            buildMenu()
            refresh()
            if game.phase == .ScoreView {
                game.scoreClose()
                game.saveLast()
                onShowScore?()
            }
            loopRunning = false
        }
    }

    private func processAnimations(queue: [Game.Animation]? = nil) async {
        var pending = queue ?? game.animations
        if queue == nil {
            game.animations.removeAll()
        }
        while true {
            guard !pending.isEmpty else { break }
            let a = pending.removeFirst()
            if let card = a.card {
                let from = field.first { $0.hand == a.player && $0.card?.id == card.id }
                let (fx, fy) = from.map { ($0.x, $0.y) } ?? TableLayout.hiddenStartCoords(a.player)
                let (tx, ty) = TableLayout.inPlayCoords(a.player)
                // hide the source card while it flies
                if let from = from {
                    field = field.filter { $0 != from }
                }
                cardAnim = CardAnim(card: card, fromX: fx, fromY: fy, toX: tx, toY: ty)
                await runAnim()
                cardAnim = nil
                pinnedOverlays.append(PlacedCard(card: card, hand: a.player, x: tx, y: ty, isInPlay: true))
            } else {
                // bid announcement: grows while flying from the bidder to center
                say = SayEvent(player: a.player, bid: a.bid, text: a.text)
                await runAnim(durationMs: 960)
                try? await Task.sleep(nanoseconds: 300_000_000)
                say = nil
            }
        }
    }

    /// In hosted games the local player may only act on turns they control
    /// (their own, or the passer's when whisting an open game); never while
    /// sitting out as the 4-player dealer.
    var localTurnAllowed: Bool {
        !hosted || (session?.hostActive != false && game.turnController() == 0)
    }

    /// Port of Draw()'s menu construction.
    private func buildMenu() {
        if !localTurnAllowed {
            menuBids = []
            selectedBid = nil
            return
        }
        switch game.phase {
        case .Negotiations:
            let bids = game.getAllowedBids().filter { !$0.pas }
            menuBids = bids
            selectedBid = bids.first { !$0.miser } ?? bids.first
        case .GameChoose:
            menuBids = game.getAllowedBids()
            selectedBid = nil
        case .Discarding:
            menuBids = []
            selectedBid = nil
            cardsToDiscard.removeAll()
        default:
            menuBids = []
            selectedBid = nil
        }
    }

    // MARK: - Interactions

    func onCardTap(_ pc: PlacedCard) {
        if busy || !localTurnAllowed { return }
        guard let card = pc.card else { return }
        if pc.isInPlay || pc.isPrikup { return }
        if game.phase == .Playing {
            if game.playCard(card, onlyCheck: true) {
                transientHint = nil
                Task {
                    busy = true
                    let (tx, ty) = TableLayout.inPlayCoords(game.playerInTurn)
                    field = field.filter { $0 != pc }
                    cardAnim = CardAnim(card: card, fromX: pc.x, fromY: pc.y, toX: tx, toY: ty)
                    await runAnim()
                    cardAnim = nil
                    pinnedOverlays.append(PlacedCard(card: card, hand: game.playerInTurn, x: tx, y: ty, isInPlay: true))
                    busy = false
                    game.playCard(card)
                    gameNext()
                }
            } else {
                if pc.hand != game.playerInTurn {
                    let aiName = game.calc.scores[game.playerInTurn].name
                    let mine = game.playerInTurn == 0
                    transientHint = L("game_wrong_hand") +
                        (mine ? L("game_wrong_hand_yours") : LF("game_wrong_hand_ai", aiName))
                } else {
                    let moves = game.getAllowedMoves()
                    if let color = moves.first?.coatColor {
                        transientHint = LF("game_must_play", "\(card)", GameTexts.trumpName(color))
                    }
                }
            }
        } else if game.phase == .Discarding {
            toggleDiscard(card)
        }
    }

    private func toggleDiscard(_ card: Card) {
        if let idx = cardsToDiscard.firstIndex(where: { $0.id == card.id }) {
            cardsToDiscard.remove(at: idx)
        } else {
            if cardsToDiscard.count >= 2 { return }
            cardsToDiscard.append(card)
        }
        field = TableLayout.computeField(game, discardSelection: cardsToDiscard)
    }

    func onCanvasTap() {
        if busy { return }
        if showTricks {
            showTricks = false
            return
        }
        if let s = session, !s.hostActive {
            // sitting 4-player dealer: taps release the current spectator stop
            // (prikup, trick, deal result or score sheet)
            if s.spectatorAwaiting {
                Task {
                    busy = true
                    let anims: [Game.Animation] = await withCheckedContinuation { continuation in
                        gameQueue.async {
                            do {
                                try s.dealerConfirm()
                            } catch {
                                NSLog("Pref: dealer confirm error: %@", "\(error)")
                            }
                            continuation.resume(returning: s.drainAnims())
                        }
                    }
                    syncHostedGame()
                    await processAnimations(queue: anims)
                    busy = false
                    buildMenu()
                    refresh()
                }
            }
            return
        }
        if !localTurnAllowed { return }
        switch game.phase {
        case .PrikupOpened:
            game.prikupClose()
            gameNext()
        case .EndTurn:
            hideDeal()
        case .EndPlay:
            game.endConfirm()
            gameNext()
        case .ScoreView:
            // hosted games treat the score view as a confirm turn
            if hosted {
                game.scoreClose()
                gameNext()
            }
        default:
            break
        }
    }

    /// Trick collection animation (port of HideDeal).
    private func hideDeal() {
        let take = field.filter { $0.isInPlay && $0.card != nil }
        let (tx, ty) = TableLayout.outOfPlayCoords(game.playerToTake)
        Task {
            busy = true
            field = field.filter { !$0.isInPlay }
            pinnedOverlays.removeAll()
            trickAnim = TrickAnim(cards: take, toX: tx, toY: ty)
            await runAnim()
            trickAnim = nil
            busy = false
            trickCollected = true
            trickCollectedAt = game.deal.totalTaken
            game.turnClose()
            gameNext()
        }
    }

    func onChoiceSelected(_ bid: Game.Bid) {
        if busy { return }
        if game.phase == .Negotiations || game.phase == .GameChoose {
            selectedBid = bid
        }
    }

    /// Port of btnChoice1_Tap.
    func onButton1() {
        if busy || !localTurnAllowed { return }
        switch game.phase {
        case .Negotiations:
            guard let bid = selectedBid else { return }
            game.makeBid(bid)
            gameNext()
        case .VistNegotiations:
            game.setVist(true)
            gameNext()
        case .GameChoose:
            guard let bid = selectedBid else { return }
            game.setContract(bid)
            gameNext()
        case .OpeningChoose:
            game.setOpeningChoice(true)
            gameNext()
        default:
            break
        }
        menuBids = []
    }

    /// Port of btnChoice2_Tap.
    func onButton2() {
        if busy || !localTurnAllowed { return }
        switch game.phase {
        case .Negotiations:
            let pas = Game.Bid()
            pas.pas = true
            game.makeBid(pas)
            gameNext()
        case .VistNegotiations:
            game.setVist(false)
            gameNext()
        case .GameChoose:
            guard let bid = selectedBid else { return }
            game.setContract(bid)
            gameNext()
        case .OpeningChoose:
            game.setOpeningChoice(false)
            gameNext()
        case .Discarding:
            doDiscard()
        default:
            break
        }
        menuBids = []
    }

    private func doDiscard() {
        if cardsToDiscard.count != 2 { return }
        game.discardCard(cardsToDiscard[0])
        game.discardCard(cardsToDiscard[1])
        cardsToDiscard.removeAll()
        gameNext()
    }

    /// Port of btnHint_Tap — runs the AI on behalf of the player (may take a moment).
    func requestAdvice() {
        if busy || hosted || !localTurnAllowed { return }
        busy = true
        thinking = true
        let game = self.game!
        Task {
            let hint: String? = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                gameQueue.async {
                    do {
                        guard let ai = game.aIs[game.playerInTurn] else {
                            continuation.resume(returning: nil)
                            return
                        }
                        switch game.phase {
                        case .Playing:
                            guard let card = try AI.playCard(ai, game) else {
                                continuation.resume(returning: nil)
                                return
                            }
                            continuation.resume(returning: LF("game_advise_play", "\(card)"))
                        case .GameChoose:
                            let contract = try AI.getContract(ai, game.getAllowedBids())
                            continuation.resume(returning: LF("game_advise_contract", GameTexts.bidTitle(contract)))
                        case .Negotiations:
                            let bid = AI.getBid(ai, game.getAllowedBids())
                            continuation.resume(returning: LF("game_advise_bid", GameTexts.bidTitle(bid)))
                        case .Discarding:
                            let discard = try AI.getDiscard(ai, game)
                            continuation.resume(returning: LF("game_advise_discard", "\(discard.0)", "\(discard.1)"))
                        default:
                            continuation.resume(returning: nil)
                        }
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
            thinking = false
            busy = false
            if let hint = hint {
                transientHint = hint
            }
        }
    }

    /// While the deal is still played, earlier tricks show as card backs.
    @Published private(set) var hidePastTricks = false

    func openTricks() {
        if busy { return }
        guard let ai = game.aIs[game.playerInTurn] else { return }
        tricks = ai.outOfPlay
        hidePastTricks = game.deal.totalTaken < 10
        tricksNames = [
            -1: game.calc.scores[game.getPrevPlayer()].name,
            0: game.calc.scores[game.playerInTurn].name,
            1: game.calc.scores[game.getNextPlayer()].name
        ]
        showTricks = true
    }

    /// Port of bntShowWithPrikup: reveal contractor's hand together with possible talon cards.
    func showHandWithPrikup(_ hand: Int) {
        if busy { return }
        showPrikupHand = hand
        field = TableLayout.computeField(game, discardSelection: cardsToDiscard, showPrikupHand: hand)
        info = buildTableInfo()
    }

    /// Back from the hand-with-talon view to the normal table.
    func hideHandWithPrikup() {
        if busy || showPrikupHand == nil { return }
        showPrikupHand = nil
        field = TableLayout.computeField(game, discardSelection: cardsToDiscard)
        info = buildTableInfo()
    }
}
