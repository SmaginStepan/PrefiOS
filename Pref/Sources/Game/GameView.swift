import SwiftUI
import PrefEngine

private struct TableStrings {
    var p0 = ""
    var p1 = ""
    var p2 = ""
    var gameInfo = ""
    var hint = ""
    var result = ""
}

/// Port of DrawField's text section.
private func buildTableStrings(_ info: TableInfo) -> TableStrings {
    var s = TableStrings()
    s.p0 = GameTexts.playerInfo(info, 0)
    s.p1 = GameTexts.playerInfo(info, 1)
    s.p2 = GameTexts.playerInfo(info, 2)

    func writeGameInfo() {
        s.p1 += ":\(info.taken[1])"
        s.p2 += ":\(info.taken[2])"
        s.p0 += ":\(info.taken[0])"
        if info.currentGameType != .Raspasy {
            s.gameInfo = LF("game_playing_fmt", info.maxBid.map { GameTexts.bidTitle($0) } ?? "")
        } else {
            s.gameInfo = L("game_playing_raspasy")
        }
    }

    switch info.phase {
    case .Discarding:
        s.hint = L("game_hint_discard")
    case .EndTurn:
        s.hint = info.playerToTake == 0
            ? L("game_hint_you_take")
            : LF("game_hint_takes", info.names[info.playerToTake])
        writeGameInfo()
    case .Playing:
        s.hint = info.playerInTurn != 0
            ? LF("game_hint_move_ai", info.names[info.playerInTurn])
            : L("game_hint_your_move")
        writeGameInfo()
    case .PrikupOpened:
        s.hint = L("game_hint_prikup")
    case .Negotiations:
        if let b = info.curentBids[1] { s.p1 += ":" + GameTexts.bidTitle(b) }
        if let b = info.curentBids[2] { s.p2 += ":" + GameTexts.bidTitle(b) }
        if let b = info.curentBids[0] { s.p0 += ":" + GameTexts.bidTitle(b) }
        s.hint = L("game_hint_bid")
    case .VistNegotiations:
        s.gameInfo = LF("game_playing_fmt", info.maxBid.map { GameTexts.bidTitle($0) } ?? "")
        if let v = info.isVister[1] { s.p1 += ":" + L(v ? "game_vist_say" : "game_pass_say") }
        if let v = info.isVister[2] { s.p2 += ":" + L(v ? "game_vist_say" : "game_pass_say") }
        if let v = info.isVister[0] { s.p0 += ":" + L(v ? "game_vist_say" : "game_pass_say") }
        if info.contractor == 1 {
            s.p1 += ":" + (info.maxBid.map { GameTexts.bidTitle($0) } ?? "")
        } else if info.contractor == 2 {
            s.p2 += ":" + (info.maxBid.map { GameTexts.bidTitle($0) } ?? "")
        }
        s.hint = L("game_hint_vist")
    case .GameChoose:
        s.p0 += ":?"
        s.hint = L("game_hint_choose")
    case .OpeningChoose:
        s.hint = L("game_hint_opening")
    case .EndPlay:
        writeGameInfo()
        if let result = info.gameResult {
            s.result = GameTexts.resultText(result, info.names)
        }
        s.hint = L("game_hint_end")
    default:
        break
    }
    return s
}

struct GameView: View {
    let onShowScore: () -> Void

    @EnvironmentObject private var app: AppState
    @StateObject private var vm = GameViewModel()
    private let images = CardImages()

    var body: some View {
        GeometryReader { geo in
            // Portrait: stretch the 480x716 canvas to fill (original behavior).
            // Landscape (iPad multitasking): aspect-fit and center the table.
            let isLandscape = geo.size.width > geo.size.height
            let scale = min(geo.size.width / TableLayout.W, geo.size.height / TableLayout.H)
            let tableW = isLandscape ? TableLayout.W * scale : geo.size.width
            let tableH = isLandscape ? TableLayout.H * scale : geo.size.height
            let kx = tableW / TableLayout.W
            let ky = tableH / TableLayout.H
            let cardW = TableLayout.S0 * kx
            let cardH = cardW * 96.0 / 70.0

            ZStack(alignment: .topLeading) {
                // Background
                Image(uiImage: images.background())
                    .resizable()
                    .frame(width: tableW, height: tableH)
                    .onTapGesture { vm.onCanvasTap() }

                let info = vm.info
                let strings = buildTableStrings(info)
                let hintText = vm.transientHint ?? (vm.thinking ? L("game_thinking") : strings.hint)

                // Cards on the table
                ForEach(vm.field + vm.pinnedOverlays) { pc in
                    Image(uiImage: images.get(pc.card))
                        .resizable()
                        .frame(width: cardW, height: cardH)
                        .offset(x: pc.x * kx, y: pc.y * ky)
                        .onTapGesture { vm.onCardTap(pc) }
                }

                // Flying card animation
                if let anim = vm.cardAnim {
                    let t = vm.animProgress
                    let x = anim.fromX + (anim.toX - anim.fromX) * t
                    let y = anim.fromY + (anim.toY - anim.fromY) * t
                    Image(uiImage: images.get(anim.card))
                        .resizable()
                        .frame(width: cardW, height: cardH)
                        .offset(x: x * kx, y: y * ky)
                }

                // Trick collection animation (cards fly to taker and shrink)
                if let anim = vm.trickAnim {
                    let t = vm.animProgress
                    let s = max(1.0 - t, 0.001)
                    ForEach(anim.cards) { pc in
                        let x = pc.x + (anim.toX - pc.x) * t
                        let y = pc.y + (anim.toY - pc.y) * t
                        Image(uiImage: images.get(pc.card))
                            .resizable()
                            .frame(width: max(cardW * s, 1), height: max(cardH * s, 1))
                            .offset(x: x * kx, y: y * ky)
                    }
                }

                // Player labels
                Text(strings.p1)
                    .foregroundColor(.white)
                    .font(.system(size: 13))
                    .frame(width: 196 * kx, alignment: .leading)
                    .offset(x: 20 * kx, y: 10 * ky)
                Text(strings.p2)
                    .foregroundColor(.white)
                    .font(.system(size: 13))
                    .frame(width: 196 * kx, alignment: .trailing)
                    .offset(x: 266 * kx, y: 10 * ky)
                Text(strings.p0)
                    .foregroundColor(.white)
                    .font(.system(size: 13))
                    .frame(width: 285 * kx, alignment: .trailing)
                    .offset(x: 177 * kx, y: 664 * ky)
                Text(strings.gameInfo)
                    .foregroundColor(.white)
                    .font(.system(size: 13))
                    .frame(width: 285 * kx, alignment: .trailing)
                    .offset(x: 177 * kx, y: 684 * ky)

                // Hint text (bottom-left "advice bubble" area)
                if !hintText.isEmpty {
                    Text(hintText)
                        .foregroundColor(.white)
                        .font(.system(size: 13))
                        .padding(6)
                        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        .frame(width: 150 * kx, alignment: .leading)
                        .offset(x: 16 * kx, y: 545 * ky)
                }

                // Deal result (EndPlay)
                if !strings.result.isEmpty {
                    Text(strings.result)
                        .foregroundColor(.white)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(Color.black.opacity(0.53), in: RoundedRectangle(cornerRadius: 8))
                        .frame(width: 353 * kx)
                        .offset(x: 63 * kx, y: 374 * ky)
                        .onTapGesture { vm.onCanvasTap() }
                }

                // Thinking indicator
                if vm.thinking {
                    ProgressView()
                        .tint(Theme.accentYellow)
                        .offset(x: 224 * kx, y: 470 * ky)
                }

                // Say bubbles (bid announcements)
                if let say = vm.say {
                    SayBubble(say: say)
                        .offset(x: (say.player == 2 ? 260.0 : 30.0) * kx, y: 88 * ky)
                }

                // Bid menu
                if !vm.busy && !vm.menuBids.isEmpty
                    && (info.phase == .Negotiations || info.phase == .GameChoose) {
                    BidMenu(vm: vm)
                        .frame(width: 203 * kx, height: 300 * ky)
                        .offset(x: 139 * kx, y: 23 * ky)
                }

                // Choice buttons
                if !vm.busy {
                    choiceButtons(info: info, kx: kx, ky: ky)
                }

                // "Layout and discard" buttons (open play against a contractor AI)
                if !vm.busy && info.showPrikupBtn1 {
                    Button { vm.showHandWithPrikup(1) } label: {
                        Text(L("game_btn_show_prikup"))
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.bordered)
                    .offset(x: 192 * kx, y: 0)
                }
                if !vm.busy && info.showPrikupBtn2 {
                    Button { vm.showHandWithPrikup(2) } label: {
                        Text(L("game_btn_show_prikup"))
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.bordered)
                    .offset(x: 192 * kx, y: 0)
                }

                // Bottom-left action buttons
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Button { vm.requestAdvice() } label: {
                            Text(L("game_btn_hint")).font(.system(size: 12)).foregroundColor(.white)
                        }
                        .buttonStyle(.bordered)
                        if info.showTricksBtn {
                            Button { vm.openTricks() } label: {
                                Text(L("game_btn_tricks")).font(.system(size: 12)).foregroundColor(.white)
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    .padding(6)
                }

                // Past tricks popup
                if vm.showTricks {
                    TricksPopup(vm: vm, images: images)
                        .frame(width: 432 * kx, height: 500 * ky)
                        .offset(x: 24 * kx, y: 18 * ky)
                }
            }
            .frame(width: tableW, height: tableH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.tableGreenDark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            vm.onShowScore = onShowScore
            vm.start(app: app, ai1Name: L("ai_name_1"), ai2Name: L("ai_name_2"))
        }
    }

    @ViewBuilder
    private func choiceButtons(info: TableInfo, kx: Double, ky: Double) -> some View {
        let phase = info.phase
        let btn1Label: String? = {
            switch phase {
            case .Negotiations: return vm.selectedBid.map { GameTexts.bidTitle($0) }
            case .VistNegotiations: return L("game_btn_whist")
            case .OpeningChoose: return L("game_btn_open")
            default: return nil
            }
        }()
        let btn2Label: String? = {
            switch phase {
            case .Negotiations: return L("game_btn_pass")
            case .VistNegotiations: return L("game_btn_pass")
            case .OpeningChoose: return L("game_btn_closed")
            case .GameChoose: return vm.selectedBid.map { GameTexts.bidTitle($0) } ?? L("game_btn_not_selected")
            case .Discarding: return L("game_btn_discard")
            default: return nil
            }
        }()
        let btn2Enabled: Bool = {
            switch phase {
            case .GameChoose: return vm.selectedBid != nil
            case .Discarding: return vm.cardsToDiscard.count == 2
            default: return true
            }
        }()
        if let label = btn1Label {
            Button { vm.onButton1() } label: {
                Text(label).frame(width: 227 * kx)
            }
            .buttonStyle(.borderedProminent)
            .offset(x: 127 * kx, y: 330 * ky)
        }
        if let label = btn2Label {
            Button { vm.onButton2() } label: {
                Text(label).frame(width: 227 * kx)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!btn2Enabled)
            .offset(x: 127 * kx, y: 385 * ky)
        }
    }
}

private struct SayBubble: View {
    let say: SayEvent
    @State private var scale = 1.0

    var body: some View {
        Text(GameTexts.sayText(say))
            .foregroundColor(Theme.accentYellow)
            .fontWeight(.bold)
            .font(.system(size: 14 * scale))
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    scale = 2.2
                }
            }
    }
}

private struct BidMenu: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        let reversed = Array(vm.menuBids.reversed())
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(reversed.enumerated()), id: \.offset) { idx, bid in
                        let selected = vm.selectedBid === bid
                        Text(GameTexts.bidTitle(bid))
                            .foregroundColor(selected ? Theme.accentYellow : .white)
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .contentShape(Rectangle())
                            .onTapGesture { vm.onChoiceSelected(bid) }
                            .id(idx)
                    }
                }
            }
            .onAppear {
                if !reversed.isEmpty {
                    proxy.scrollTo(reversed.count - 1, anchor: .bottom)
                }
            }
        }
        .background(Color(white: 0.83).opacity(0.17))
        .border(Color.white, width: 1)
    }
}

private struct TricksPopup: View {
    @ObservedObject var vm: GameViewModel
    let images: CardImages

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
                    ForEach(Array(vm.tricks.enumerated()), id: \.offset) { _, take in
                        HStack {
                            Text(vm.tricksNames[take.firstMovePerformer] ?? "")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity)
                            HStack(spacing: 0) {
                                if let prikup = take.prikupMove {
                                    Image(uiImage: images.get(prikup))
                                        .resizable().frame(width: 34, height: 47)
                                }
                                Image(uiImage: images.get(take.nextMove))
                                    .resizable().frame(width: 34, height: 47)
                                Image(uiImage: images.get(take.prevMove))
                                    .resizable().frame(width: 34, height: 47)
                                Image(uiImage: images.get(take.myMove))
                                    .resizable().frame(width: 34, height: 47)
                            }
                            .frame(maxWidth: .infinity)
                            Text(vm.tricksNames[take.takenBy] ?? "")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            Button { vm.showTricks = false } label: {
                Text(L("game_btn_close"))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(8)
        .background(Color(red: 0, green: 0x9B / 255.0, blue: 0), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1))
    }
}
