import Foundation

/// Mirrors PrefServer/src/protocol.ts and the Android net/Protocol.kt —
/// treat the Android code as the schema and match field names byte-for-byte.
/// `rules` and relayed `data` are opaque JSON.

public struct SeatInfo: Codable {
    public var name: String
    public var kind: String
    public var connected: Bool

    public init(name: String, kind: String, connected: Bool) {
        self.name = name
        self.kind = kind
        self.connected = connected
    }
}

public struct RoomInfo: Codable {
    public var id: String
    public var name: String
    public var rules: JSONValue?
    public var maxSeats: Int
    public var phase: String
    public var hasPassword: Bool
    public var hostName: String
    public var seats: [SeatInfo?]

    private enum CodingKeys: String, CodingKey {
        case id, name, rules, maxSeats, phase, hasPassword, hostName, seats
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        rules = try c.decodeIfPresent(JSONValue.self, forKey: .rules)
        maxSeats = try c.decode(Int.self, forKey: .maxSeats)
        phase = try c.decode(String.self, forKey: .phase)
        hasPassword = try c.decodeIfPresent(Bool.self, forKey: .hasPassword) ?? false
        hostName = try c.decodeIfPresent(String.self, forKey: .hostName) ?? ""
        // seats may contain nulls for empty positions
        if var seatArr = try? c.nestedUnkeyedContainer(forKey: .seats) {
            var res: [SeatInfo?] = []
            while !seatArr.isAtEnd {
                if try seatArr.decodeNil() {
                    res.append(nil)
                } else {
                    res.append(try seatArr.decode(SeatInfo.self))
                }
            }
            seats = res
        } else {
            seats = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(rules, forKey: .rules)
        try c.encode(maxSeats, forKey: .maxSeats)
        try c.encode(phase, forKey: .phase)
        try c.encode(hasPassword, forKey: .hasPassword)
        try c.encode(hostName, forKey: .hostName)
        var seatArr = c.nestedUnkeyedContainer(forKey: .seats)
        for seat in seats {
            if let seat = seat {
                try seatArr.encode(seat)
            } else {
                try seatArr.encodeNil()
            }
        }
    }
}

/// Client → server messages, discriminated by "type".
public enum ClientMsg {
    case hello(playerId: String, name: String)
    case listRooms
    case createRoom(name: String, rules: JSONValue, maxSeats: Int, password: String?)
    case reopenRoom(roomId: String, name: String, rules: JSONValue, maxSeats: Int, password: String?, seats: [ReopenSeat?])
    case join(roomId: String, password: String?)
    case leave
    case kick(seat: Int)
    case addBot(seat: Int?)
    case start
    case send(toSeat: Int?, data: JSONValue)

    public struct ReopenSeat: Codable {
        public var playerId: String?
        public var name: String
        public var kind: String

        public init(playerId: String?, name: String, kind: String) {
            self.playerId = playerId
            self.name = name
            self.kind = kind
        }
    }
}

extension ClientMsg: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, playerId, name, rules, maxSeats, password, roomId, seats, seat, toSeat, data
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let playerId, let name):
            try c.encode("hello", forKey: .type)
            try c.encode(playerId, forKey: .playerId)
            try c.encode(name, forKey: .name)
        case .listRooms:
            try c.encode("list_rooms", forKey: .type)
        case .createRoom(let name, let rules, let maxSeats, let password):
            try c.encode("create_room", forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(rules, forKey: .rules)
            try c.encode(maxSeats, forKey: .maxSeats)
            try c.encodeIfPresent(password, forKey: .password) // absent, never null
        case .reopenRoom(let roomId, let name, let rules, let maxSeats, let password, let seats):
            try c.encode("reopen_room", forKey: .type)
            try c.encode(roomId, forKey: .roomId)
            try c.encode(name, forKey: .name)
            try c.encode(rules, forKey: .rules)
            try c.encode(maxSeats, forKey: .maxSeats)
            try c.encodeIfPresent(password, forKey: .password)
            var seatArr = c.nestedUnkeyedContainer(forKey: .seats)
            for seat in seats {
                if let seat = seat {
                    try seatArr.encode(seat)
                } else {
                    try seatArr.encodeNil()
                }
            }
        case .join(let roomId, let password):
            try c.encode("join", forKey: .type)
            try c.encode(roomId, forKey: .roomId)
            try c.encodeIfPresent(password, forKey: .password)
        case .leave:
            try c.encode("leave", forKey: .type)
        case .kick(let seat):
            try c.encode("kick", forKey: .type)
            try c.encode(seat, forKey: .seat)
        case .addBot(let seat):
            try c.encode("add_bot", forKey: .type)
            try c.encodeIfPresent(seat, forKey: .seat)
        case .start:
            try c.encode("start", forKey: .type)
        case .send(let toSeat, let data):
            try c.encode("send", forKey: .type)
            try c.encodeIfPresent(toSeat, forKey: .toSeat)
            try c.encode(data, forKey: .data)
        }
    }
}

/// Server → client messages, discriminated by "type".
public enum ServerMsg {
    case welcome
    case rooms([RoomInfo])
    case roomCreated(roomId: String)
    case roomState(RoomInfo)
    case joined(roomId: String, seat: Int)
    case started
    case kicked(roomId: String?)
    case roomClosed(roomId: String?, reason: String?)
    case left
    case hostMsg(data: JSONValue)
    case playerMsg(fromSeat: Int, data: JSONValue)
    case error(code: String, message: String)
}

extension ServerMsg: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type, rooms, roomId, room, seat, reason, data, fromSeat, code, message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "welcome":
            self = .welcome
        case "rooms":
            self = .rooms(try c.decodeIfPresent([RoomInfo].self, forKey: .rooms) ?? [])
        case "room_created":
            self = .roomCreated(roomId: try c.decode(String.self, forKey: .roomId))
        case "room_state":
            self = .roomState(try c.decode(RoomInfo.self, forKey: .room))
        case "joined":
            self = .joined(
                roomId: try c.decode(String.self, forKey: .roomId),
                seat: try c.decode(Int.self, forKey: .seat)
            )
        case "started":
            self = .started
        case "kicked":
            self = .kicked(roomId: try c.decodeIfPresent(String.self, forKey: .roomId))
        case "room_closed":
            self = .roomClosed(
                roomId: try c.decodeIfPresent(String.self, forKey: .roomId),
                reason: try c.decodeIfPresent(String.self, forKey: .reason)
            )
        case "left":
            self = .left
        case "host_msg":
            self = .hostMsg(data: try c.decode(JSONValue.self, forKey: .data))
        case "player_msg":
            self = .playerMsg(
                fromSeat: try c.decode(Int.self, forKey: .fromSeat),
                data: try c.decode(JSONValue.self, forKey: .data)
            )
        case "error":
            self = .error(
                code: try c.decode(String.self, forKey: .code),
                message: try c.decodeIfPresent(String.self, forKey: .message) ?? ""
            )
        default:
            throw PrefError("unknown server message type: \(type)")
        }
    }
}

/// Client-owned payload stored in the room's opaque `rules` field.
public struct RoomRules: Codable {
    public var gameRules: GameRules
    public var limit: Int

    public init(gameRules: GameRules = GameRules(), limit: Int = 10) {
        self.gameRules = gameRules
        self.limit = limit
    }

    private enum CodingKeys: String, CodingKey {
        case gameRules, limit
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameRules = try c.decodeIfPresent(GameRules.self, forKey: .gameRules) ?? GameRules()
        limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? 10
    }
}
