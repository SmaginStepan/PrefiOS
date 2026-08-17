import SwiftUI
@preconcurrency import PrefEngine

@MainActor
final class GuestGameViewModel: ObservableObject {
    @Published private(set) var state: GameMsg.State?
    @Published var selectedBid: Game.Bid?
    @Published var discardSel: [Card] = []

    // one pulka file per guest session, overwritten on every save
    private let calcCreated = Int64(Date().timeIntervalSince1970 * 1000)

    /// Auto-confirm everything until the deal's score sheet appears.
    @Published var autoConfirmDeal = false
    @Published var showLayout = false
    @Published var showTakes = false
    @Published var scorePeek = false
    private var autoSaved = false

    func onState(_ s: GameMsg.State) {
        let prevKind = state?.ask?.kind
        state = s
        if s.ask?.kind != prevKind {
            selectedBid = nil
        }
        if s.ask?.kind != "discard" {
            discardSel.removeAll()
        }
        if s.layout == nil { showLayout = false }
        if s.takes == nil { showTakes = false }
        if let scores = s.scores {
            autoConfirmDeal = false // the score sheet waits for a real tap
            scorePeek = false
            if s.ended && !autoSaved {
                autoSaved = true
                _ = saveScoreSheet(scores)
            }
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
    @State private var offerStep = 0
    @State private var offerN = 0
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
                    // player-side auto-confirm: everything except the score sheet
                    if vm?.autoConfirmDeal == true && s.scores == nil
                        && s.yourTurn && s.ask?.kind == "confirm" {
                        act(GameMsg.Act(confirm: true))
                    }
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

                let shownField = vm.showLayout ? (st.layout ?? st.field) : st.field
                ForEach(shownField) { pc in
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

                // Confirm asks: tap anywhere to continue
                if ask?.kind == "confirm" {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: tableW, height: tableH)
                        .onTapGesture { act(GameMsg.Act(confirm: true)) }
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
                    .offset(x: 142 * kx, y: 70 * ky)
                }

                // ask buttons
                if let ask = ask {
                    askButtons(ask, kx: kx, ky: ky)
                }

                // bottom-left action buttons (parity with the host table)
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        if st.takes != nil && st.info.showTricksBtn {
                            Button { vm.showTakes = true } label: {
                                Text(L("game_btn_tricks")).font(.system(size: 12)).foregroundColor(.white)
                            }
                            .buttonStyle(.bordered)
                        }
                        if st.standings != nil && st.scores == nil {
                            Button { vm.scorePeek = true } label: {
                                Text(L("game_btn_score")).font(.system(size: 12)).foregroundColor(.white)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button { vm.autoConfirmDeal.toggle() } label: {
                            Text(L("game_btn_auto"))
                                .font(.system(size: 12))
                                .foregroundColor(vm.autoConfirmDeal ? Theme.accentYellow : .white)
                        }
                        .buttonStyle(.bordered)
                        if Agreements.canOffer(st.info) {
                            Button { offerStep = 1 } label: {
                                Text(L("game_btn_offer")).font(.system(size: 12)).foregroundColor(.white)
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    .padding(6)
                }

                // layout-and-discard toggle sits where the host has it (top center)
                if st.layout != nil {
                    Button { vm.showLayout.toggle() } label: {
                        Text(L(vm.showLayout ? "game_btn_hide_prikup" : "game_btn_show_prikup"))
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.bordered)
                    .offset(x: 192 * kx, y: 30 * ky)
                }

                // agreement offer menus + pending dialog (shared with the host table)
                AgreementUi(
                    info: st.info,
                    offerStep: $offerStep,
                    offerN: $offerN,
                    onOffer: { taken in
                        offerStep = 0
                        act(GameMsg.Act(offer: taken))
                    },
                    pending: st.offer,
                    onRespond: { agree in act(GameMsg.Act(agree: agree)) },
                    kx: kx, ky: ky, tableW: tableW, tableH: tableH
                )

                // on-demand standings peek
                if vm.scorePeek, st.scores == nil, let snap = st.standings {
                    ScoreOverlay(
                        snap: snap,
                        onTap: { vm.scorePeek = false }
                    )
                    .frame(width: tableW, height: tableH)
                }

                // past tricks popup (same rules as the host: earlier tricks
                // face-down until the deal's play is over)
                if vm.showTakes, let takes = st.takes {
                    GuestTakesPopup(
                        takes: takes,
                        names: [-1: st.info.names[1], 0: st.info.names[0], 1: st.info.names[2]],
                        allFaceUp: st.info.phase == .EndPlay,
                        images: images,
                        onClose: { vm.showTakes = false }
                    )
                    .frame(width: 432 * kx, height: 500 * ky)
                    .offset(x: 24 * kx, y: 18 * ky)
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

    private struct GuestTakesPopup: View {
        let takes: [TakeSnap]
        let names: [Int: String]
        let allFaceUp: Bool
        let images: CardImages
        let onClose: () -> Void

        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text(L("game_trick_led"))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                    Spacer()
                        .frame(maxWidth: .infinity)
                    Text(L("game_trick_took"))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(takes.enumerated()), id: \.offset) { idx, take in
                            // only the last trick may be reviewed until the deal ends
                            let faceDown = !allFaceUp && idx < takes.count - 1
                            HStack {
                                Text(names[take.first] ?? "")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12))
                                    .frame(maxWidth: .infinity)
                                HStack(spacing: 0) {
                                    if let prikup = take.prikup {
                                        Image(uiImage: images.get(faceDown ? nil : prikup))
                                            .resizable().frame(width: 34, height: 47)
                                    }
                                    Image(uiImage: images.get(faceDown ? nil : take.next))
                                        .resizable().frame(width: 34, height: 47)
                                    Image(uiImage: images.get(faceDown ? nil : take.prev))
                                        .resizable().frame(width: 34, height: 47)
                                    Image(uiImage: images.get(faceDown ? nil : take.my))
                                        .resizable().frame(width: 34, height: 47)
                                }
                                .frame(maxWidth: .infinity)
                                Text(names[take.taker] ?? "")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                Button(action: onClose) {
                    Text(L("game_btn_close"))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(8)
            .background(Color(red: 0, green: 0x9B / 255.0, blue: 0), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1))
        }
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
            .frame(width: 180 * kx, alignment: .center)
            .offset(x: 142 * kx, y: 330 * ky)
        }
        if let (label, enabled, action) = btn2 {
            Button(action: action) {
                Text(label).lineLimit(1).minimumScaleFactor(0.6).frame(width: 130 * kx)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!enabled)
            .frame(width: 180 * kx, alignment: .center)
            .offset(x: 142 * kx, y: 385 * ky)
        }
    }
}
