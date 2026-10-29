import SwiftUI
import PrefEngine

/// The monthly season: this month's rules (fixed for everyone), your run, the
/// season board and the Play button. The run itself is offline; the network is
/// used to learn the season once, to post the total and to show the board.
/// Port of Android's SeasonScreen.
struct SeasonView: View {
    let onPlay: () -> Void
    let onToMenu: () -> Void

    @EnvironmentObject private var app: AppState
    @State private var state: SeasonState? = Seasons.load()
    @State private var loading = true
    @State private var reload = 0

    private let myId = AppSettings().playerId

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.usesGroupingSeparator = false
        return f
    }()

    private func fmt(_ v: Double) -> String {
        Self.formatter.string(from: NSNumber(value: v)) ?? ""
    }

    private var playerName: String {
        let settings = AppSettings()
        return settings.isDefaultPlayerName ? L("default_player_name") : settings.playerName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L("menu_season"))
                    .font(.system(size: 40))
                    .foregroundColor(Theme.accentGold)
                    .padding(.bottom, 8)

                if let s = state {
                    content(s)
                } else {
                    Text(L(loading ? "season_loading" : "season_need_network"))
                        .font(.system(size: 16))
                        .padding(.vertical, 12)
                    if !loading {
                        Button { reload += 1 } label: { Text(L("season_retry")) }
                            .buttonStyle(.borderedProminent)
                    }
                }

                Button { onToMenu() } label: { Text(L("hs_to_menu")) }
                    .buttonStyle(.bordered)
                    .padding(.top, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Theme.background)
        .task(id: reload) {
            loading = true
            if let s = await Seasons.refresh() {
                await Seasons.submitPending(s, playerName: playerName)
                await Seasons.refreshBoard(s)
            }
            let fresh = Seasons.load()
            // a new season has started: last month's unfinished pool is void
            if let fresh = fresh, let old = app.seasonGame?.seasonSeed, old != fresh.seed {
                app.seasonGame = nil
            }
            state = fresh
            loading = false
        }
    }

    @ViewBuilder
    private func content(_ s: SeasonState) -> some View {
        let over = Seasons.isOver(s)
        let days = Seasons.daysLeft(s)
        let status: String = over ? L("season_over")
            : (days <= 1 ? L("season_last_day") : LF("season_days_left_fmt", days))
        Text("\(s.seasonId) · \(status)")
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.7))
            .padding(.bottom, 16)

        Text(L("season_rules_title")).font(.system(size: 18)).foregroundColor(Theme.accentGold)
        let cfg = Seasons.config(s)
        ForEach(Array(rulesLineTexts(cfg.rules, limit: cfg.limit, full: true).enumerated()), id: \.offset) { _, line in
            Text(line).font(.system(size: 15)).padding(.vertical, 2)
        }

        Text(LF("season_progress_fmt", s.poolsClosed, s.nextDealIndex))
            .font(.system(size: 15))
            .padding(.top, 16)
        Text(LF("season_total_fmt", fmt(Double(s.total10) / 10.0)))
            .font(.system(size: 20))
            .foregroundColor(Theme.accentGold)
            .padding(.top, 4)
            .padding(.bottom, 8)
        Text(L("season_note"))
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.6))
            .padding(.bottom, 12)

        if !over {
            // a run in progress (a started pool or any closed one) continues
            let resuming = s.nextDealIndex > 0 || (app.seasonGame?.seasonDealIndex ?? 0) > 0
            Button {
                if app.seasonGame == nil {
                    app.seasonGame = Seasons.newPoolGame(
                        s, playerName: playerName, ai1Name: L("ai_name_1"), ai2Name: L("ai_name_2")
                    )
                }
                app.seasonMode = true
                onPlay()
            } label: {
                Text(L(resuming ? "menu_continue" : "season_play"))
            }
            .buttonStyle(.borderedProminent)
        }

        Text(L("season_board_title"))
            .font(.system(size: 18))
            .foregroundColor(Theme.accentGold)
            .padding(.top, 24)
            .padding(.bottom, 8)
        if s.board.isEmpty {
            Text(L("season_board_empty"))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        ForEach(Array(s.board.enumerated()), id: \.offset) { i, row in
            let color: Color = row.playerId == myId ? Color(red: 1, green: 0xEB / 255.0, blue: 0x3B / 255.0) : .gray
            HStack {
                Text("\(i + 1).").font(.system(size: 18)).foregroundColor(color)
                Text(row.name).font(.system(size: 18)).foregroundColor(color)
                Spacer()
                Text(fmt(row.score)).font(.system(size: 18)).foregroundColor(color)
            }
            .padding(.vertical, 3)
        }
    }
}
