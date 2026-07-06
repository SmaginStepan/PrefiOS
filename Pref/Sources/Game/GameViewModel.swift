import Foundation
import SwiftUI
// The engine is deliberately non-Sendable: all engine work is confined to the
// view model's serial gameQueue, matching the original app's BackgroundWorker.
@preconcurrency import PrefEngine

/// Immutable snapshot of everything the table UI needs to render texts.
struct TableInfo {
    var phase: GamePhase = .NotStarted
    var names: [String] = ["", "", ""]
    var dealer: Int = 0
    var taken: [Int] = [0, 0, 0]
    var currentGameType: GameType = .Raspasy
    var contractor: Int = 0
    var isVister: [Int: Bool] = [:]
    var curentBids: [Int: Game.Bid] = [:]
    var maxBid: Game.Bid?
    var playerToTake: Int = 0
    var playerInTurn: Int = 0
    var gameResult: Calculation.GameResult?
    var showPrikupBtn1: Bool = false
    var showPrikupBtn2: Bool = false
    var showTricksBtn: Bool = false
}

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
    private func runAnim(durationMs: Double = 300) async {
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
        var isVister: [Int: Bool] = [:]
        for (k, v) in game.isVister.entries {
            isVister[k] = v
        }
        var curentBids: [Int: Game.Bid] = [:]
        for (k, v) in game.curentBids.entries {
            curentBids[k] = v
        }
        return TableInfo(
            phase: game.phase,
            names: game.calc.scores.map { $0.name },
            dealer: game.calc.dealer,
            taken: game.deal.hands.map { $0.taken },
            currentGameType: game.currentGameType,
            contractor: game.contractor,
            isVister: isVister,
            curentBids: curentBids,
            maxBid: game.maxBid,
            playerToTake: game.playerToTake,
            playerInTurn: game.playerInTurn,
            gameResult: game.phase == .EndPlay ? game.getGameResult() : nil,
            showPrikupBtn1: (game.phase == .Playing || game.phase == .EndTurn)
                && (game.currentGameType == .Normal || game.currentGameType == .Miser)
                && game.contractor == 1 && game.opening && showPrikupHand != 1,
            showPrikupBtn2: (game.phase == .Playing || game.phase == .EndTurn)
                && (game.currentGameType == .Normal || game.currentGameType == .Miser)
                && game.contractor == 2 && game.opening && showPrikupHand != 2,
            showTricksBtn: game.phase == .Playing || game.phase == .EndTurn
        )
    }

    /// Recompute all published render state from the (quiescent) game.
    private func refresh() {
        showPrikupHand = nil
        field = TableLayout.computeField(game, discardSelection: cardsToDiscard)
        pinnedOverlays.removeAll()
        info = buildTableInfo()
    }

    func gameNext() {
        if loopRunning { return }
        loopRunning = true
        busy = true
        thinking = true
        transientHint = nil
        let game = self.game!
        Task {
            let error: Error? = await withCheckedContinuation { continuation in
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

    private func processAnimations() async {
        while true {
            guard !game.animations.isEmpty else { break }
            let a = game.animations.removeFirst()
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
                say = SayEvent(player: a.player, bid: a.bid, text: a.text)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                say = nil
            }
        }
    }

    /// Port of Draw()'s menu construction.
    private func buildMenu() {
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
        if busy { return }
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
        switch game.phase {
        case .PrikupOpened:
            game.prikupClose()
            gameNext()
        case .EndTurn:
            hideDeal()
        case .EndPlay:
            game.endConfirm()
            gameNext()
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
        if busy { return }
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
        if busy { return }
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
        if busy { return }
        busy = true
        thinking = true
        let game = self.game!
        Task {
            let hint: String? = await withCheckedContinuation { continuation in
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

    func openTricks() {
        if busy { return }
        guard let ai = game.aIs[game.playerInTurn] else { return }
        tricks = ai.outOfPlay
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
}
