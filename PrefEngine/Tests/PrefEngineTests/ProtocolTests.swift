import XCTest
@testable import PrefEngine

/// Wire-compatibility tests: the JSON samples are the exact fixtures from the
/// Android ProtocolTest.kt (the Android code defines the schema).
final class ProtocolTests: XCTestCase {

    func testEncodesClientMessagesWithTypeDiscriminator() throws {
        let hello = try WireJSON.encodeToString(ClientMsg.hello(playerId: "abc12345", name: "Степан"))
        XCTAssertTrue(hello.contains("\"type\":\"hello\""))
        XCTAssertTrue(hello.contains("\"playerId\":\"abc12345\""))

        let rules = JSONValue.object(["limit": .int(10)])
        let create = try WireJSON.encodeToString(
            ClientMsg.createRoom(name: "Игра", rules: rules, maxSeats: 4, password: nil)
        )
        XCTAssertTrue(create.contains("\"type\":\"create_room\""))
        XCTAssertTrue(create.contains("\"maxSeats\":4"))
        // zod .optional() rejects explicit null — the field must be absent
        XCTAssertFalse(create.contains("password"), "null password must be omitted")

        let addBot = try WireJSON.encodeToString(ClientMsg.addBot(seat: nil))
        XCTAssertFalse(addBot.contains("seat"), "null seat must be omitted")

        let send = try WireJSON.encodeToString(ClientMsg.send(toSeat: nil, data: .object(["t": .string("act")])))
        XCTAssertFalse(send.contains("toSeat"), "null toSeat must be omitted")
    }

    func testDecodesServerMessages() throws {
        // samples captured from the real pref-server
        let roomsMsg = try WireJSON.decodeFromString(
            ServerMsg.self,
            """
            {"type":"rooms","rooms":[{"id":"R7DCDW","name":"Test game","rules":{"gameType":"Sochy","limit":10},"maxSeats":3,"phase":"open","hasPassword":true,"hostName":"Host","seats":[{"name":"Host","kind":"human","connected":true},null,null]}]}
            """
        )
        guard case .rooms(let rooms) = roomsMsg else {
            return XCTFail("expected rooms")
        }
        XCTAssertEqual(1, rooms.count)
        XCTAssertEqual("R7DCDW", rooms[0].id)
        XCTAssertEqual(3, rooms[0].seats.count)
        XCTAssertEqual("Host", rooms[0].seats[0]?.name)
        XCTAssertNil(rooms[0].seats[1])

        let joinedMsg = try WireJSON.decodeFromString(
            ServerMsg.self,
            #"{"type":"joined","roomId":"R7DCDW","seat":1}"#
        )
        guard case .joined(_, let seat) = joinedMsg else {
            return XCTFail("expected joined")
        }
        XCTAssertEqual(1, seat)

        let errMsg = try WireJSON.decodeFromString(
            ServerMsg.self,
            #"{"type":"error","code":"bad_password","message":"Wrong password"}"#
        )
        guard case .error(let code, _) = errMsg else {
            return XCTFail("expected error")
        }
        XCTAssertEqual("bad_password", code)

        let relayedMsg = try WireJSON.decodeFromString(
            ServerMsg.self,
            #"{"type":"player_msg","fromSeat":2,"data":{"action":"bid","contract":6}}"#
        )
        guard case .playerMsg(let fromSeat, _) = relayedMsg else {
            return XCTFail("expected player_msg")
        }
        XCTAssertEqual(2, fromSeat)
    }

    func testGameMsgActOmitsAbsentFields() throws {
        let act = try WireJSON.encodeToString(GameMsg.act(GameMsg.Act(vist: true)))
        XCTAssertTrue(act.contains("\"t\":\"act\""))
        XCTAssertTrue(act.contains("\"vist\":true"))
        for absent in ["bid", "contract", "opening", "discard", "play", "confirm"] {
            XCTAssertFalse(act.contains("\"\(absent)\""), "\(absent) must be omitted")
        }

        // decode an Android-encoded act
        let decoded = try WireJSON.decodeFromString(
            GameMsg.self,
            #"{"t":"act","play":{"value":14,"coatColor":0}}"#
        )
        guard case .act(let a) = decoded else {
            return XCTFail("expected act")
        }
        XCTAssertEqual(14, a.play?.value)
        XCTAssertEqual(0, a.play?.coatColor)
        XCTAssertNil(a.bid)
    }

    func testStateRoundTripAndIntKeyedMaps() throws {
        // Android encodes Int-keyed maps as JSON objects with string keys and
        // enums by name; make sure we produce and accept exactly that.
        var info = TableInfo()
        info.phase = .Negotiations
        var bids = OrderedIntDict<Game.Bid>()
        let bid = Game.Bid()
        bid.trump = 4
        bid.contract = 6
        bids[1] = bid
        info.curentBids = bids
        var isVister = OrderedIntDict<Bool>()
        isVister[2] = true
        info.isVister = isVister

        let state = GameMsg.state(GameMsg.State(
            field: [PlacedCard(card: Card(value: 7, coatColor: 2), hand: 0, x: 1.5, y: 2.0)],
            info: info,
            yourTurn: true,
            ask: Ask("bid", bids: [bid])
        ))
        let wire = try WireJSON.encodeToString(state)
        XCTAssertTrue(wire.contains("\"t\":\"state\""))
        XCTAssertTrue(wire.contains("\"phase\":\"Negotiations\""), "enum must serialize by name")
        XCTAssertTrue(wire.contains("\"curentBids\":{\"1\":"), "Int-keyed map must be an object with string keys")
        XCTAssertTrue(wire.contains("\"isVister\":{\"2\":true}"))
        XCTAssertFalse(wire.contains("\"scores\""), "absent scores must be omitted")
        XCTAssertFalse(wire.contains("null"), "no explicit nulls anywhere")

        let back = try WireJSON.decodeFromString(GameMsg.self, wire)
        guard case .state(let s) = back else {
            return XCTFail("expected state")
        }
        XCTAssertEqual(1, s.field.count)
        XCTAssertEqual(7, s.field[0].card?.value)
        XCTAssertTrue(s.yourTurn)
        XCTAssertEqual(6, s.info.curentBids[1]?.contract)
        XCTAssertEqual(true, s.info.isVister[2])
        XCTAssertEqual("bid", s.ask?.kind)
    }

    func testRoomRulesPayload() throws {
        // {"gameRules": <GameRules by field name>, "limit": n}
        let rules = GameRules()
        rules.gameType = .Leningrad
        let payload = try JSONValue.from(RoomRules(gameRules: rules, limit: 20))
        let text = try WireJSON.encodeToString(payload)
        XCTAssertTrue(text.contains("\"gameType\":\"Leningrad\""))
        XCTAssertTrue(text.contains("\"limit\":20"))
        XCTAssertTrue(text.contains("\"stalindgrad\""), "all GameRules fields must be present")

        let back = try payload.decode(RoomRules.self)
        XCTAssertEqual(.Leningrad, back.gameRules.gameType)
        XCTAssertEqual(20, back.limit)

        // lenient decode of a minimal Android payload
        let minimal = try WireJSON.decodeFromString(
            RoomRules.self,
            #"{"gameRules":{"gameType":"Sochy"},"limit":10,"unknownField":1}"#
        )
        XCTAssertEqual(.Sochy, minimal.gameRules.gameType)
    }
}
