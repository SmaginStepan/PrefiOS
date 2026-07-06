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
        myName = settings.playerName

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
            currentRoom = room
        case .started:
            started = true
        case .left:
            currentRoom = nil
            mySeat = nil
            started = false
        case .kicked:
            currentRoom = nil
            mySeat = nil
            started = false
            notice = "kicked"
        case .roomClosed:
            currentRoom = nil
            mySeat = nil
            started = false
            notice = "room_closed"
        case .error(let code, _):
            notice = code
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
        limit: Int
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
        guard let payload = try? JSONValue.from(RoomRules(gameRules: rules, limit: limit)) else { return }
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
