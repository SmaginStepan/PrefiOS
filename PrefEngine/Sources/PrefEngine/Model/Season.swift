import Foundation

/// Everything about a season that every player must agree on is derived from
/// the season seed the server hands out, so no rules ever travel separately.
/// The draw order is part of the contract (a literal port of Android's
/// SeasonConfig; do not reorder):
///
///   limit(4: 10,20,40,60) · game type(3) · all-pass progression(3) ·
///   all-pass exit(3) · exit after a played misère(2) · whist(2) ·
///   consolation(2) · talon consolation(2) · first dealer(3)
///
/// Each draw is SeasonRandom(seed,"config",0).nextInt(n) indexing the enum's
/// declaration order (or false/true). The game type applies the same presets as
/// the settings screen; under Rostov the progression is forced to "none" (the
/// draw is still consumed, so the sequence never shifts).
public enum SeasonConfig {

    public static let limits = [10, 20, 40, 60]

    // the enums' declaration order, as Kotlin's values() — the draws index it
    private static let types: [RulesGameType] = [.Sochy, .Leningrad, .Rostov]
    private static let progressions: [RaspasyProgression] = [.NoProgression1, .Arifm1233, .Geom1244]
    private static let exits: [RaspasyExit] = [.Easy6, .Med677, .Hard678]
    private static let vists: [VistType] = [.HalfResponsibility, .FullResponsibility]
    private static let consolations: [ConsolationType] = [.Gentlemen, .Zlob]

    public struct Config {
        public let limit: Int
        public let rules: GameRules
        public let firstDealer: Int
    }

    public static func derive(_ seedHex: String) -> Config {
        let rng = SeasonRandom.forPurpose(seedHex, "config", 0)
        // the draws below are order-dependent: keep them sequential statements
        let limit = limits[rng.nextInt(limits.count)]
        let type = types[rng.nextInt(3)]
        let progression = progressions[rng.nextInt(3)]
        let exit = exits[rng.nextInt(3)]
        let miserExit = rng.nextInt(2) == 1
        let vist = vists[rng.nextInt(2)]
        let consolation = consolations[rng.nextInt(2)]
        let talonConsolation = rng.nextInt(2) == 1
        let firstDealer = rng.nextInt(3)

        let rules = GameRules()
        rules.gameType = type
        switch type {
        case .Sochy:
            rules.ending = .Each
            rules.scoring = .Normal
            rules.consolationBonus = .Normal
        case .Leningrad:
            rules.ending = .Sum
            rules.scoring = .Leningrad
            rules.consolationBonus = .Normal
        case .Rostov:
            rules.ending = .Each
            rules.scoring = .Normal
            rules.consolationBonus = .Max10
        }
        rules.raspasyProgression = type == .Rostov ? .NoProgression1 : progression
        rules.raspasyExit = exit
        rules.miserRaspExit = miserExit
        rules.vist = vist
        rules.consolation = consolation
        rules.prikupConsolation = talonConsolation
        return Config(limit: limit, rules: rules, firstDealer: firstDealer)
    }
}

public struct SeasonRow: Codable {
    public var playerId: String
    public var name: String
    public var score10: Int64

    public var score: Double {
        Double(score10) / 10.0
    }

    public init(playerId: String, name: String, score10: Int64) {
        self.playerId = playerId
        self.name = name
        self.score10 = score10
    }
}

/// The player's run through the current season, kept on the device.
public final class SeasonState: Codable {
    public var seasonId = ""
    public var seed = ""
    public var startsAt: Int64 = 0
    public var endsAt: Int64 = 0

    /// first deal of the next pool, and who deals it
    public var nextDealIndex = 0
    public var nextDealer = 0

    /// sum of every closed pool's settlement, in tenths of a whist (may be negative)
    public var total10: Int64 = 0
    public var poolsClosed = 0

    /// how many closed pools the server's copy of the total already includes
    public var submittedPools = 0

    /// the board as last fetched, for offline viewing
    public var board: [SeasonRow] = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case seasonId, seed, startsAt, endsAt, nextDealIndex, nextDealer, total10,
             poolsClosed, submittedPools, board
    }

    // lenient decode: a missing field keeps its default
    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seasonId = try c.decodeIfPresent(String.self, forKey: .seasonId) ?? ""
        seed = try c.decodeIfPresent(String.self, forKey: .seed) ?? ""
        startsAt = try c.decodeIfPresent(Int64.self, forKey: .startsAt) ?? 0
        endsAt = try c.decodeIfPresent(Int64.self, forKey: .endsAt) ?? 0
        nextDealIndex = try c.decodeIfPresent(Int.self, forKey: .nextDealIndex) ?? 0
        nextDealer = try c.decodeIfPresent(Int.self, forKey: .nextDealer) ?? 0
        total10 = try c.decodeIfPresent(Int64.self, forKey: .total10) ?? 0
        poolsClosed = try c.decodeIfPresent(Int.self, forKey: .poolsClosed) ?? 0
        submittedPools = try c.decodeIfPresent(Int.self, forKey: .submittedPools) ?? 0
        board = try c.decodeIfPresent([SeasonRow].self, forKey: .board) ?? []
    }
}

/// The season run: one continuous walk through the shared deal sequence,
/// played as consecutive pools. Nothing here needs the network except learning
/// the season seed once per season and posting the total.
public enum Seasons {

    private static let file = "season.json"

    public static func load() -> SeasonState? {
        guard let text = PrefStorage.readText(file) else { return nil }
        return try? PrefStorage.decodeFromString(SeasonState.self, text)
    }

    public static func save(_ state: SeasonState) {
        PrefStorage.writeText(file, PrefStorage.encodeToString(state))
    }

    /// A running-total board: the total may fall and go below zero (server
    /// rule for "total:" ids).
    public static func boardName(_ state: SeasonState) -> String {
        "total:\(state.seasonId)"
    }

    public static func config(_ state: SeasonState) -> SeasonConfig.Config {
        SeasonConfig.derive(state.seed)
    }

    /// Whole days left (rounded up); 0 once the season is over.
    public static func daysLeft(_ state: SeasonState, now: Int64 = Int64(Date().timeIntervalSince1970)) -> Int {
        now >= state.endsAt ? 0 : Int(((state.endsAt - now) + 86399) / 86400)
    }

    public static func isOver(_ state: SeasonState, now: Int64 = Int64(Date().timeIntervalSince1970)) -> Bool {
        now >= state.endsAt
    }

    /// Asks the server which season is running. A new season id starts a fresh
    /// run (and drops the previous season's unfinished game); the same id keeps
    /// the player's progress. Returns the saved state, or nil when there is
    /// none and the server could not be reached.
    public static func refresh() async -> SeasonState? {
        let old = load()
        guard let info = await ScoreClient.fetchSeason() else { return old }
        if let old = old, old.seasonId == info.seasonId {
            old.startsAt = info.startsAt
            old.endsAt = info.endsAt
            save(old)
            return old
        }
        let fresh = SeasonState()
        fresh.seasonId = info.seasonId
        fresh.seed = info.seed
        fresh.startsAt = info.startsAt
        fresh.endsAt = info.endsAt
        fresh.nextDealer = SeasonConfig.derive(info.seed).firstDealer
        // NOTE (ported as is): Android calls deleteFamily on a name with no '_',
        // which deletes nothing; the Season screen drops a stale game whose seed
        // differs instead. Same observable behaviour here.
        PrefStorage.deleteFamily(Game.seasonGameFile)
        save(fresh)
        return fresh
    }

    /// A new pool that continues the run's deal sequence.
    public static func newPoolGame(_ state: SeasonState, playerName: String, ai1Name: String, ai2Name: String) -> Game {
        let cfg = config(state)
        let game = Game()
        game.calc = Calculation(playersCount: 3, limit: cfg.limit)
        game.calc.rules = cfg.rules.clone()
        game.calc.scores[0].name = playerName
        game.calc.scores[1].name = ai1Name
        game.calc.scores[2].name = ai2Name
        game.calc.dealer = state.nextDealer
        game.aIs = OrderedIntDict()
        game.phase = .NotStarted
        game.seasonSeed = state.seed
        game.seasonDealIndex = state.nextDealIndex
        return game
    }

    /// A pool closed with `settlement` whists for the player. Counted once per
    /// pool, even if the result screen is closed twice.
    public static func poolClosed(_ state: SeasonState, _ game: Game, settlement: Double) {
        if game.seasonDealIndex <= state.nextDealIndex { return }
        state.total10 += roundToLongHalfUp(settlement * 10)
        state.poolsClosed += 1
        state.nextDealIndex = game.seasonDealIndex
        state.nextDealer = game.calc.dealer
        save(state)
    }

    /// A pool has closed since the server last heard from us (any total,
    /// negative included).
    public static func needsSubmit(_ state: SeasonState) -> Bool {
        state.poolsClosed > state.submittedPools
    }

    /// Posts the current total after every closed pool; safe to call any time.
    public static func submitPending(_ state: SeasonState, playerName: String) async {
        if !needsSubmit(state) { return }
        let outcome = await ScoreClient.submit(
            playerId: AppSettings().playerId,
            name: playerName,
            score10: state.total10,
            deviceTs: Int64(Date().timeIntervalSince1970),
            board: boardName(state)
        )
        if outcome != .retry {
            state.submittedPools = state.poolsClosed
            save(state)
        }
    }

    /// Refreshes the cached season board.
    public static func refreshBoard(_ state: SeasonState) async {
        guard let top = await ScoreClient.fetchTop(limit: 10, board: boardName(state)) else { return }
        state.board = top.map { SeasonRow(playerId: $0.player_id, name: $0.name, score10: $0.score) }
        save(state)
    }
}
