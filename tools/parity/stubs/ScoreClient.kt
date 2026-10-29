package com.an0obIs.pref.net
object ScoreClient {
    data class SeasonInfo(val seasonId: String, val startsAt: Long, val endsAt: Long, val seed: String)
    data class Entry(val rank: Int, val player_id: String, val name: String, val score: Long)
    enum class SubmitOutcome { ACCEPTED, DROP, RETRY }
    fun fetchSeason(): SeasonInfo? = null
    fun fetchTop(limit: Int = 10, board: String = "alltime"): List<Entry>? = null
    fun submit(playerId: String, name: String, score10: Long, deviceTs: Long, board: String = "alltime"): SubmitOutcome = SubmitOutcome.RETRY
}
