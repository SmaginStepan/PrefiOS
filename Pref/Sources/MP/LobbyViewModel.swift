import Foundation
import SwiftUI
@preconcurrency import PrefEngine

@MainActor
final class LobbyViewModel: ObservableObject {

    private let client = LobbyClient()

    @Published private(set) var conn = ConnState.disconnected
    @Published private(set) var rooms: [RoomInfo] = []
    @Published private(set) var currentRoom: RoomInfo?
    @Published private(set) var mySeat: Int?
    @Published private(set) var started = false

    /// Transient server error / event code; the UI maps it to a localized text.
    @Published var notice: String?

    /// A saved pulka the host wants to resume from when the game starts.
    @Published var loadedCalc: Calculation?

    @Published private(set) var myName = ""

    /// Relayed game payloads: host receives (fromSeat, data); guests receive data.
    var onPlayerAct: ((Int, JSONValue) -> Void)?
    var onHostState: ((JSONValue) -> Void)?

    func sendGameToSeat(_ seat: Int, _ data: JSONValue) {
        client.send(.send(toSeat: seat, data: data))
    }

    func sendGameToHost(_ data: JSONValue) {
        client.send(.send(toSeat: nil, data: data))
    }

    private var startedOnce = false
    private var keeperTask: Task<Void, Never>?

    func start() {
        if startedOnce { return }
        startedOnce = true
        let settings = AppSettings()
        // blank = never customized; the UI substitutes the localized default
        myName = settings.isDefaultPlayerName ? "" : settings.playerName

        client.onState = { [weak self] state in
            self?.conn = state
        }
        client.onMessage = { [weak self] msg in
            self?.onMessage(msg)
        }
        // connection keeper + lobby polling
        keeperTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                if self.conn == .disconnected {
                    let s = AppSettings()
                    self.client.connect(playerId: s.playerId, name: s.playerName)
                } else if self.conn == .connected && self.currentRoom == nil {
                    self.client.send(.listRooms)
                }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    private func onMessage(_ msg: ServerMsg) {
        switch msg {
        case .welcome:
            client.send(.listRooms)
        case .rooms(let list):
            rooms = list
        case .roomCreated:
            mySeat = 0
        case .joined(_, let seat):
            mySeat = seat
        case .roomState(let room):
            let prev = currentRoom
            currentRoom = room
            // a newcomer while a pulka is loaded: seat them on their column
            if loadedCalc != nil && isHost && !started {
                let prevNames = Set((prev?.seats ?? []).compactMap { $0?.name })
                if room.seats.contains(where: { $0 != nil && !prevNames.contains($0!.name) }) {
                    arrangeByPulka()
                }
            }
        case .started:
            started = true
        case .left:
            currentRoom = nil
            mySeat = nil
            started = false
            loadedCalc = nil
        case .kicked:
            currentRoom = nil
            mySeat = nil
            started = false
            loadedCalc = nil
            notice = "kicked"
        case .roomClosed(_, let reason):
            currentRoom = nil
            mySeat = nil
            started = false
            loadedCalc = nil
            notice = reason == "host_disconnected" ? "host_disconnected" : "room_closed"
        case .error(let code, let message):
            // transient throttling must not interrupt play with a dialog
            if code == "rate_limited" {
                NSLog("PrefNet: rate limited: %@", message)
            } else {
                notice = code
            }
        case .hostMsg(let data):
            onHostState?(data)
        case .playerMsg(let fromSeat, let data):
            onPlayerAct?(fromSeat, data)
        }
    }

    var isHost: Bool {
        mySeat == 0
    }

    /// Persist a changed nickname and re-announce it before create/join.
    private func ensureName(_ name: String) {
        let n = String(name.trimmingCharacters(in: .whitespaces).prefix(24))
        if n.isEmpty || n == myName { return }
        let settings = AppSettings()
        settings.playerName = n
        myName = n
        client.send(.hello(playerId: settings.playerId, name: n))
    }

    func refresh() {
        if conn == .connected {
            client.send(.listRooms)
        }
    }

    func createRoom(
        playerName: String,
        roomName: String,
        maxSeats: Int,
        password: String?,
        preset: RulesGameType,
        limit: Int,
        autoConfirmSec: Int = 0
    ) {
        ensureName(playerName)
        let rules = GameRules()
        rules.gameType = preset
        switch preset {
        case .Sochy:
            rules.vist = .FullResponsibility
            rules.consolation = .Zlob
            rules.ending = .Each
            rules.scoring = .Normal
            rules.consolationBonus = .Normal
        case .Leningrad:
            rules.vist = .HalfResponsibility
            rules.consolation = .Gentlemen
            rules.ending = .Sum
            rules.scoring = .Leningrad
            rules.consolationBonus = .Normal
        case .Rostov:
            rules.raspasyProgression = .NoProgression1
            rules.vist = .HalfResponsibility
            rules.consolation = .Gentlemen
            rules.ending = .Each
            rules.scoring = .Normal
            rules.consolationBonus = .Max10
        }
        guard let payload = try? JSONValue.from(RoomRules(gameRules: rules, limit: limit, autoConfirmSec: autoConfirmSec)) else { return }
        let pwd = (password?.isEmpty == false) ? password : nil
        client.send(.createRoom(name: roomName, rules: payload, maxSeats: maxSeats, password: pwd))
    }

    func join(roomId: String, password: String?, playerName: String) {
        ensureName(playerName)
        let pwd = (password?.isEmpty == false) ? password : nil
        client.send(.join(roomId: roomId, password: pwd))
    }

    func leave() {
        client.send(.leave)
    }

    func kick(_ seat: Int) {
        client.send(.kick(seat: seat))
    }

    func addBot() {
        client.send(.addBot(seat: nil))
    }

    func swapSeats(_ a: Int, _ b: Int) {
        if a != b && a > 0 && b > 0 {
            client.send(.swapSeats(a: a, b: b))
        }
    }

    /// Move name-matched players onto their saved-pulka columns (visual order).
    func arrangeByPulka() {
        guard let calc = loadedCalc, let room = currentRoom else { return }
        if !isHost || started { return }
        // simulate on a copy, emit the swap sequence that realizes it
        var sim = room.seats
        let n = min(room.maxSeats, calc.playersCount)
        for col in 1..<n {
            let want = calc.scores[col].name
                .trimmingCharacters(in: .whitespaces).lowercased()
            let cur = sim.indices.contains(col)
                ? sim[col]?.name.trimmingCharacters(in: .whitespaces).lowercased() : nil
            if cur == want { continue }
            let from = (1..<room.maxSeats).first { j in
                j != col && sim.indices.contains(j)
                    && sim[j]?.name.trimmingCharacters(in: .whitespaces).lowercased() == want
            }
            guard let from = from else { continue }
            sim.swapAt(col, from)
            swapSeats(col, from)
        }
    }

    func startGame() {
        client.send(.start)
    }

    /// Lenient parse of a room's opaque rules payload for lobby display.
    nonisolated func parseRules(_ rules: JSONValue?) -> RoomRules? {
        guard let rules = rules else { return nil }
        return try? rules.decode(RoomRules.self)
    }

    deinit {
        keeperTask?.cancel()
        client.disconnect()
    }
}
