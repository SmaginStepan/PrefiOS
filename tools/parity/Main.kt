import com.an0obIs.pref.ai.AI
import com.an0obIs.pref.model.*
import java.nio.file.Files
import kotlin.math.roundToLong

// Plays whole seasons with every seat on the bots and prints one line per deal.
// The Swift engine runs the identical driver (SeasonTests.testDumpSeasonBotRun);
// the two outputs must be identical line for line.
fun main(args: Array<String>) {
    PrefStorage.init(Files.createTempDirectory("parity").toFile())
    val seed = args[0]
    val pools = args[1].toInt()
    val cfg = SeasonConfig.derive(seed)
    val state = SeasonState().also {
        it.seed = seed; it.seasonId = "parity"; it.nextDealer = cfg.firstDealer
    }
    println("CONFIG limit=${cfg.limit} type=${cfg.rules.gameType} prog=${cfg.rules.raspasyProgression} exit=${cfg.rules.raspasyExit} dealer=${cfg.firstDealer}")
    for (pool in 0 until pools) {
        val game = Seasons.newPoolGame(state, "Me", "West", "East")
        var logged = 0
        game.next()
        var steps = 0
        var fallbacks = 0
        while (game.phase != GamePhase.Ended && steps < 200000) {
            steps++
            try {
                AI.makeMove(game)
            } catch (e: Exception) {
                // identical to HostGameSession's fallback for rare positions
                if (game.phase == GamePhase.Playing) {
                    fallbacks++
                    game.playCard(game.getAllowedMoves().first())
                    game.next()
                } else {
                    throw e
                }
            }
            while (logged < game.calc.gameLog.size) {
                val r = game.calc.gameLog[logged]
                val t = r.taken.toSortedMap().values.joinToString(",")
                val v = r.visters.sorted().joinToString(",")
                println("P$pool D$logged ${r.gameType} c=${r.contractor} k=${r.contract} t=$t v=$v d=${r.dealer} m=${r.multiplier} rng=${game.botRng?.state} idx=${game.seasonDealIndex}")
                logged++
            }
        }
        game.calc.calc() // the results screen computes the final settlement
        val sc = game.calc.scores
        val sheet = (0..2).joinToString(" ") { i ->
            "[${sc[i].pulya}/${sc[i].gora}/${sc[i].visty.toSortedMap().entries.joinToString(",") { "${it.key}=${it.value}" }}]"
        }
        val settle = (0..2).joinToString(",") { (sc[it].score * 10).roundToLong().toString() }
        println("POOL $pool deals=${game.calc.gameLog.size} steps=$steps fallbacks=$fallbacks sheet=$sheet settlement10=$settle")
        Seasons.poolClosed(state, game, sc[0].score)
    }
    println("TOTAL total10=${state.total10} pools=${state.poolsClosed} next=${state.nextDealIndex} dealer=${state.nextDealer}")
}
