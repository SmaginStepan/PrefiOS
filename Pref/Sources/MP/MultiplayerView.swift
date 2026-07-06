import SwiftUI
import PrefEngine

private func noticeText(_ code: String) -> String {
    switch code {
    case "kicked": return L("mp_err_kicked")
    case "room_closed": return L("mp_err_room_closed")
    case "bad_password": return L("mp_err_bad_password")
    case "room_full": return L("mp_err_room_full")
    case "playing": return L("mp_err_playing")
    default: return LF("mp_err_generic", code)
    }
}

private func rulesSummary(_ vm: LobbyViewModel, _ room: RoomInfo) -> String {
    guard let parsed = vm.parseRules(room.rules) else { return "" }
    let type: String
    switch parsed.gameRules.gameType {
    case .Sochy: type = L("settings_game_sochy")
    case .Leningrad: type = L("settings_game_leningrad")
    case .Rostov: type = L("settings_game_rostov")
    }
    return "\(type) · \(parsed.limit)"
}

struct MultiplayerView: View {
    let onBack: () -> Void

    @StateObject private var vm = LobbyViewModel()

    var body: some View {
        Group {
            if let room = vm.currentRoom {
                // live game (3-player only until the 4p engine mode lands;
                // started 4-seat rooms keep the RoomView with its stub note)
                if vm.started && room.maxSeats == 3 {
                    if vm.isHost {
                        MpHostView(lobbyVm: vm, room: room)
                    } else {
                        MpGuestView(lobbyVm: vm)
                    }
                } else {
                    RoomView(vm: vm, room: room, onBack: onBack)
                }
            } else {
                LobbyView(vm: vm)
            }
        }
        .background(Theme.background)
        .onAppear { vm.start() }
        .alert(
            vm.notice.map { noticeText($0) } ?? "",
            isPresented: Binding(get: { vm.notice != nil }, set: { if !$0 { vm.notice = nil } })
        ) {
            Button(L("close"), role: .cancel) { vm.notice = nil }
        }
    }
}

/// The host runs the real game table on top of HostGameSession.
private struct MpHostView: View {
    @ObservedObject var lobbyVm: LobbyViewModel
    let room: RoomInfo

    @State private var config: HostedConfig?

    var body: some View {
        Group {
            if let config = config {
                GameView(onShowScore: {}, hostedConfig: config)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if config == nil {
                let names = (0..<3).map { i in room.seats.indices.contains(i) ? (room.seats[i]?.name ?? "?") : "?" }
                let kinds: [SeatKind] = (0..<3).map { i in
                    let seat = room.seats.indices.contains(i) ? room.seats[i] : nil
                    if i == 0 { return .local }
                    if seat?.kind == "bot" { return .bot }
                    return .remote
                }
                let c = HostedConfig(
                    names: names,
                    seatKinds: kinds,
                    sendToSeat: { seat, state in
                        if let data = try? JSONValue.from(GameMsg.state(state)) {
                            Task { @MainActor in
                                lobbyVm.sendGameToSeat(seat, data)
                            }
                        }
                    }
                )
                lobbyVm.onPlayerAct = { seat, el in
                    if let msg = try? el.decode(GameMsg.self), case .act(let act) = msg {
                        c.deliverAct?(seat, act)
                    } else {
                        NSLog("PrefNet: bad act payload")
                    }
                }
                config = c
            }
        }
    }
}

private struct LobbyView: View {
    @ObservedObject var vm: LobbyViewModel

    @State private var showCreate = false
    @State private var joinFor: RoomInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("mp_title"))
                .font(.system(size: 40))
                .foregroundColor(Theme.accentGold)
                .padding(.bottom, 8)

            if vm.conn != .connected {
                HStack {
                    ProgressView().padding(.trailing, 12)
                    Text(L(vm.conn == .connecting ? "mp_connecting" : "mp_disconnected"))
                }
            } else {
                Button {
                    showCreate = true
                } label: {
                    Text(L("mp_create")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical, 8)

                if vm.rooms.isEmpty {
                    Text(L("mp_no_rooms"))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 16)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(vm.rooms, id: \.id) { r in
                                let occupied = r.seats.filter { $0 != nil }.count
                                Button {
                                    if r.phase == "open" {
                                        joinFor = r
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text((r.hasPassword ? "🔒 " : "") + r.name)
                                                .font(.system(size: 20, weight: .medium))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text(LF("mp_players_fmt", occupied, r.maxSeats))
                                                .font(.system(size: 14))
                                                .foregroundColor(Theme.accentGold)
                                        }
                                        Text(LF("mp_host_fmt", r.hostName) + "  ·  " + rulesSummary(vm, r))
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .sheet(isPresented: $showCreate) {
            CreateRoomSheet(defaultPlayerName: vm.myName) { playerName, name, seats, password, preset, limit in
                vm.createRoom(playerName: playerName, roomName: name, maxSeats: seats, password: password, preset: preset, limit: limit)
                showCreate = false
            } onDismiss: {
                showCreate = false
            }
        }
        .sheet(item: Binding(
            get: { joinFor.map { JoinTarget(room: $0) } },
            set: { joinFor = $0?.room }
        )) { target in
            JoinRoomSheet(room: target.room, defaultPlayerName: vm.myName) { playerName, pwd in
                vm.join(roomId: target.room.id, password: pwd, playerName: playerName)
                joinFor = nil
            } onDismiss: {
                joinFor = nil
            }
        }
    }
}

private struct JoinTarget: Identifiable {
    let room: RoomInfo
    var id: String { room.id }
}

private struct JoinRoomSheet: View {
    let room: RoomInfo
    let defaultPlayerName: String
    let onJoin: (String, String?) -> Void
    let onDismiss: () -> Void

    @State private var playerName = ""
    @State private var pwd = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField(L("mp_your_name"), text: Binding(
                    get: { playerName },
                    set: { playerName = String($0.prefix(24)) }
                ))
                if room.hasPassword {
                    Section(header: Text(L("mp_password_title"))) {
                        TextField(L("mp_password_label"), text: $pwd)
                    }
                }
            }
            .navigationTitle(room.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("mp_join")) {
                        onJoin(playerName, pwd)
                    }
                    .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("close")) { onDismiss() }
                }
            }
        }
        .onAppear {
            if playerName.isEmpty {
                playerName = defaultPlayerName
            }
        }
        .presentationDetents([.medium])
    }
}

private struct CreateRoomSheet: View {
    let defaultPlayerName: String
    let onCreate: (String, String, Int, String?, RulesGameType, Int) -> Void
    let onDismiss: () -> Void

    @State private var playerName = ""
    @State private var name = ""
    @State private var seats = 3
    @State private var password = ""
    @State private var preset = RulesGameType.Sochy
    @State private var limitText = "10"

    var body: some View {
        NavigationStack {
            Form {
                TextField(L("mp_your_name"), text: Binding(
                    get: { playerName },
                    set: { playerName = String($0.prefix(24)) }
                ))
                TextField(L("mp_room_name"), text: Binding(
                    get: { name },
                    set: { name = String($0.prefix(32)) }
                ))
                Section(header: Text(L("mp_seats"))) {
                    Picker("", selection: $seats) {
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    ForEach([RulesGameType.Sochy, .Leningrad, .Rostov], id: \.self) { p in
                        Button {
                            preset = p
                        } label: {
                            HStack {
                                Image(systemName: preset == p ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(Theme.accentGold)
                                Text(presetLabel(p))
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                TextField(L("sheet_limit_label"), text: $limitText)
                    .keyboardType(.numberPad)
                TextField(L("mp_password_optional"), text: Binding(
                    get: { password },
                    set: { password = String($0.prefix(32)) }
                ))
            }
            .navigationTitle(L("mp_create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("mp_create")) {
                        onCreate(
                            playerName.trimmingCharacters(in: .whitespaces),
                            name.trimmingCharacters(in: .whitespaces),
                            seats,
                            password,
                            preset,
                            Int(limitText) ?? 10
                        )
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                        || playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("close")) { onDismiss() }
                }
            }
        }
        .onAppear {
            if playerName.isEmpty {
                playerName = defaultPlayerName
                name = defaultPlayerName
            }
        }
    }

    private func presetLabel(_ p: RulesGameType) -> String {
        switch p {
        case .Sochy: return L("settings_game_sochy")
        case .Leningrad: return L("settings_game_leningrad")
        case .Rostov: return L("settings_game_rostov")
        }
    }
}

private struct RoomView: View {
    @ObservedObject var vm: LobbyViewModel
    let room: RoomInfo
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(room.name)
                .font(.system(size: 32))
                .foregroundColor(Theme.accentGold)
            Text(LF("mp_room_code_fmt", room.id) + "  ·  " + rulesSummary(vm, room))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 16)

            ForEach(0..<room.maxSeats, id: \.self) { i in
                let seat = room.seats.indices.contains(i) ? room.seats[i] : nil
                HStack {
                    Text(seatLabel(seat, index: i))
                        .font(.system(size: 19))
                        .foregroundColor(seat == nil ? .white.opacity(0.4) : .white)
                    Spacer()
                    if vm.isHost && i > 0 && seat != nil && !vm.started {
                        Button {
                            vm.kick(i)
                        } label: {
                            Text(L("mp_kick")).font(.system(size: 13))
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            if vm.started {
                Text(L("mp_started_stub"))
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accentGold)
                    .padding(.vertical, 24)
            } else if !vm.isHost {
                Text(L("mp_waiting_host"))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 24)
            }

            VStack(spacing: 8) {
                if vm.isHost && !vm.started {
                    let occupied = room.seats.filter { $0 != nil }.count
                    let full = occupied == room.maxSeats && room.seats.allSatisfy { $0 == nil || $0!.connected }
                    HStack(spacing: 8) {
                        Button {
                            vm.addBot()
                        } label: {
                            Text(L("mp_add_bot"))
                                .lineLimit(1)
                                .fixedSize()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(occupied >= room.maxSeats)
                        Button {
                            vm.startGame()
                        } label: {
                            Text(L("mp_start"))
                                .lineLimit(1)
                                .fixedSize()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!full)
                    }
                }
                Button {
                    vm.leave()
                } label: {
                    Text(L("mp_leave")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }

    private func seatLabel(_ seat: SeatInfo?, index: Int) -> String {
        guard let seat = seat else { return "—" }
        var res = seat.name
        if index == vm.mySeat {
            res += " " + L("mp_you")
        }
        if seat.kind == "bot" {
            res += " · " + L("mp_bot")
        }
        if seat.kind == "human" && !seat.connected {
            res += " · " + L("mp_offline")
        }
        return res
    }
}
