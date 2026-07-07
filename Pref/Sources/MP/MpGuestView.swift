import SwiftUI
@preconcurrency import PrefEngine

@MainActor
final class GuestGameViewModel: ObservableObject {
    @Published private(set) var state: GameMsg.State?
    @Published var selectedBid: Game.Bid?
    @Published var discardSel: [Card] = []

    // one pulka file per guest session, overwritten on every save
    private let calcCreated = Int64(Date().timeIntervalSince1970 * 1000)

    func onState(_ s: GameMsg.State) {
        let prevKind = state?.ask?.kind
        state = s
        if s.ask?.kind != prevKind {
            selectedBid = nil
        }
        if s.ask?.kind != "discard" {
            discardSel.removeAll()
        }
    }

    /// Save the host's score snapshot as a regular pulka file (guest view: self = player 0).
    func saveScoreSheet(_ snap: ScoreSnap) -> Bool {
        let n = snap.names.count
        let c = Calculation(playersCount: n, limit: snap.limit)
        c.created = calcCreated
        c.dealer = snap.dealer
        for i in 0..<n {
            c.scores[i].name = snap.names[i]
            c.scores[i].pulya = snap.pulya[i]
            c.scores[i].gora = snap.gora[i]
            for j in 0..<n where i != j {
                c.scores[i].visty[j] = snap.visty.indices.contains(i) ? snap.visty[i][j] : 0
            }
        }
        c.save()
        return true
    }
}

/// Thin client: renders the host's per-viewer snapshots and answers Asks.
struct MpGuestView: View {
    @ObservedObject var lobbyVm: LobbyViewModel

    @StateObject private var vm = GuestGameViewModel()
    private let images = CardImages()

    private func act(_ a: GameMsg.Act) {
        if let data = try? JSONValue.from(GameMsg.act(a)) {
            lobbyVm.sendGameToHost(data)
        }
    }

    var body: some View {
        Group {
            if let st = vm.state {
                table(st)
            } else {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    Text(L("mp_waiting_host")).foregroundColor(.white)
                }
            }
        }
        .onAppear {
            lobbyVm.onHostState = { [weak vm] el in
                if let msg = try? el.decode(GameMsg.self), case .state(let s) = msg {
                    vm?.onState(s)
                } else {
                    NSLog("PrefNet: bad game payload")
                }
            }
        }
    }

    @ViewBuilder
    private func table(_ st: GameMsg.State) -> some View {
        let ask = st.yourTurn ? st.ask : nil

        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let scale = min(geo.size.width / TableLayout.W, geo.size.height / TableLayout.H)
            let tableW = isLandscape ? TableLayout.W * scale : geo.size.width
            let tableH = isLandscape ? TableLayout.H * scale : geo.size.height
            let kx = tableW / TableLayout.W
            let ky = tableH / TableLayout.H
            // Slightly smaller than the 70-unit layout slot (58-unit hand step),
            // so a thin gap separates the cards in every hand. Sized by the
            // smaller axis scale: when the canvas is stretched non-uniformly
            // (iPad portrait), cards keep their aspect and still fit the
            // 79-unit row step instead of overlapping vertically.
            let cardW = 56.0 * min(kx, ky)
            let cardH = cardW * 96.0 / 70.0

            ZStack(alignment: .topLeading) {
                Image(uiImage: images.background())
                    .resizable()
                    .frame(width: tableW, height: tableH)
                    .onTapGesture {
                        if ask?.kind == "confirm" {
                            act(GameMsg.Act(confirm: true))
                        }
                    }

                let strings = buildTableStrings(st.info, mp: true)
                let hintText = st.badMove ? L("mp_bad_move") : (st.ended ? L("mp_game_over") : strings.hint)

                ForEach(st.field) { pc in
                    let selected = pc.card != nil && vm.discardSel.contains { $0.id == pc.card!.id }
                    Image(uiImage: images.get(pc.card))
                        .resizable()
                        .frame(width: cardW, height: cardH)
                        .offset(x: pc.x * kx, y: pc.y * ky - (selected ? 14 : 0))
                        .onTapGesture {
                            guard let card = pc.card else { return }
                            if pc.isInPlay || pc.isPrikup { return }
                            switch ask?.kind {
                            // own cards, or the passer's when whisting an open
                            // game (the host lists them in ask.allowed)
                            case "play":
                                if pc.hand == 0 || ask?.allowed?.contains(where: { $0.id == card.id }) == true {
                                    act(GameMsg.Act(play: card))
                                }
                            case "discard":
                                if pc.hand != 0 { return }
                                if let idx = vm.discardSel.firstIndex(where: { $0.id == card.id }) {
                                    vm.discardSel.remove(at: idx)
                                } else if vm.discardSel.count < 2 {
                                    vm.discardSel.append(card)
                                }
                            default:
                                break
                            }
                        }
                }

                Text(strings.p1)
                    .foregroundColor(.white).font(.system(size: 13))
                    .frame(width: 196 * kx, alignment: .leading)
                    .offset(x: 20 * kx, y: 10 * ky)
                Text(strings.p2)
                    .foregroundColor(.white).font(.system(size: 13))
                    .frame(width: 196 * kx, alignment: .trailing)
                    .offset(x: 266 * kx, y: 10 * ky)
                Text(strings.p0)
                    .foregroundColor(.white).font(.system(size: 13))
                    .frame(width: 285 * kx, alignment: .trailing)
                    .offset(x: 177 * kx, y: 664 * ky)
                Text(strings.gameInfo)
                    .foregroundColor(.white).font(.system(size: 13))
                    .frame(width: 285 * kx, alignment: .trailing)
                    .offset(x: 177 * kx, y: 694 * ky)

                if let sitOut = st.info.sitOutName {
                    SitOutBadge(name: sitOut, kx: kx, ky: ky)
                } else if !st.info.names[st.info.dealer].isEmpty {
                    DealerBadge(dealer: st.info.dealer, kx: kx, ky: ky)
                }

                if !hintText.isEmpty {
                    Text(hintText)
                        .foregroundColor(.white).font(.system(size: 13))
                        .padding(6)
                        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        .frame(width: 150 * kx, alignment: .leading)
                        .offset(x: 16 * kx, y: 545 * ky)
                }

                if let snap = st.scores {
                    ScoreOverlay(
                        snap: snap,
                        onSave: { vm.saveScoreSheet(snap) },
                        onTap: {
                            if ask?.kind == "confirm" {
                                act(GameMsg.Act(confirm: true))
                            }
                        }
                    )
                    .frame(width: tableW, height: tableH)
                }

                if !strings.result.isEmpty {
                    Text(strings.result)
                        .foregroundColor(.white).font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(Color.black.opacity(0.53), in: RoundedRectangle(cornerRadius: 8))
                        .frame(width: 353 * kx)
                        .offset(x: 63 * kx, y: 374 * ky)
                        .onTapGesture {
                            if ask?.kind == "confirm" {
                                act(GameMsg.Act(confirm: true))
                            }
                        }
                }

                // bid / contract menu
                if let ask = ask, ask.kind == "bid" || ask.kind == "contract", let bids = ask.bids, !bids.isEmpty {
                    let choices = Array(bids.filter { !$0.pas }.reversed())
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(choices.enumerated()), id: \.offset) { _, bid in
                                Text(GameTexts.bidTitle(bid))
                                    .foregroundColor(vm.selectedBid === bid ? Theme.accentYellow : .white)
                                    .font(.system(size: 20))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .contentShape(Rectangle())
                                    .onTapGesture { vm.selectedBid = bid }
                            }
                        }
                    }
                    .frame(width: 180 * kx, height: 240 * ky)
                    .background(Color(red: 0x12 / 255.0, green: 0x3B / 255.0, blue: 0x16 / 255.0).opacity(0.4))
                    .border(Color(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0).opacity(0.4), width: 1)
                    .offset(x: 150 * kx, y: 70 * ky)
                }

                // ask buttons
                if let ask = ask {
                    askButtons(ask, kx: kx, ky: ky)
                }

                if st.ended {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                lobbyVm.leave()
                            } label: {
                                Text(L("mp_leave")).foregroundColor(.white)
                            }
                            .buttonStyle(.bordered)
                            .padding(12)
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: tableW, height: tableH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.tableGreenDark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func askButtons(_ ask: Ask, kx: Double, ky: Double) -> some View {
        let btn1: (String, () -> Void)? = {
            switch ask.kind {
            case "bid":
                if let bid = vm.selectedBid {
                    return (GameTexts.bidTitle(bid), { act(GameMsg.Act(bid: bid)) })
                }
                return nil
            case "vist":
                return (L("game_btn_whist"), { act(GameMsg.Act(vist: true)) })
            case "opening":
                return (L("game_btn_open"), { act(GameMsg.Act(opening: true)) })
            default:
                return nil
            }
        }()
        let btn2: (String, Bool, () -> Void)? = {
            switch ask.kind {
            case "bid":
                return (L("game_btn_pass"), true, {
                    let pas: Game.Bid
                    if let serverPas = ask.bids?.first(where: { $0.pas }) {
                        pas = serverPas
                    } else {
                        pas = Game.Bid()
                        pas.pas = true
                    }
                    act(GameMsg.Act(bid: pas))
                })
            case "vist":
                return (L("game_btn_pass"), true, { act(GameMsg.Act(vist: false)) })
            case "opening":
                return (L("game_btn_closed"), true, { act(GameMsg.Act(opening: false)) })
            case "contract":
                return (
                    vm.selectedBid.map { GameTexts.bidTitle($0) } ?? L("game_btn_not_selected"),
                    vm.selectedBid != nil,
                    {
                        if let bid = vm.selectedBid {
                            act(GameMsg.Act(contract: bid))
                        }
                    }
                )
            case "discard":
                return (L("game_btn_discard"), vm.discardSel.count == 2, {
                    act(GameMsg.Act(discard: vm.discardSel))
                })
            default:
                return nil
            }
        }()
        if let (label, action) = btn1 {
            Button(action: action) {
                Text(label).lineLimit(1).minimumScaleFactor(0.6).frame(width: 130 * kx)
            }
            .buttonStyle(.borderedProminent)
            .offset(x: 175 * kx, y: 330 * ky)
        }
        if let (label, enabled, action) = btn2 {
            Button(action: action) {
                Text(label).lineLimit(1).minimumScaleFactor(0.6).frame(width: 130 * kx)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!enabled)
            .offset(x: 175 * kx, y: 385 * ky)
        }
    }
}
