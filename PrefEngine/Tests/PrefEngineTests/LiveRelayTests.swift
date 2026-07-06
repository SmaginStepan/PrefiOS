import XCTest
@testable import PrefEngine

/// End-to-end check against the LIVE server (wss://preferansmaster.com/ws):
/// one connection hosts a real HostGameSession (own seat bot-driven), a second
/// connection is a scripted guest answering Asks — a full game must complete
/// through the production lobby + relay.
///
/// Network test: runs only with PREF_LIVE_TEST=1 in the environment.
final class LiveRelayTests: XCTestCase {

    private final class WS: NSObject, URLSessionWebSocketDelegate {
        let name: String
        private var session: URLSession!
        private var task: URLSessionWebSocketTask?
        private let opened = DispatchSemaphore(value: 0)
        var onMessage: ((ServerMsg) -> Void)?

        init(name: String) {
            self.name = name
            super.init()
            session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        }

        func connect(_ url: String) -> Bool {
            let t = session.webSocketTask(with: URL(string: url)!)
            task = t
            receive(t)
            t.resume()
            return opened.wait(timeout: .now() + 15) == .success
        }

        func send(_ msg: ClientMsg) {
            guard let text = try? WireJSON.encodeToString(msg) else { return }
            task?.send(.string(text)) { _ in }
        }

        func close() {
            task?.cancel(with: .normalClosure, reason: nil)
        }

        private func receive(_ t: URLSessionWebSocketTask) {
            t.receive { [weak self] result in
                guard let self = self else { return }
                if case .success(let message) = result {
                    if case .string(let text) = message,
                       let msg = try? WireJSON.decodeFromString(ServerMsg.self, text) {
                        self.onMessage?(msg)
                    }
                    self.receive(t)
                }
            }
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
            opened.signal()
        }
    }

    func testFullGameOverLiveRelay() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["PREF_LIVE_TEST"] == "1",
            "live network test; run with PREF_LIVE_TEST=1"
        )
        let url = "wss://preferansmaster.com/ws"
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pref-live-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        PrefStorage.initialize(filesDir: dir)

        // All game/session work runs on one serial queue (like the app).
        let gameQueue = DispatchQueue(label: "live-test-game")

        let host = WS(name: "host")
        let guest = WS(name: "guest")

        var roomId: String?
        let roomCreated = expectation(description: "room created")
        let guestJoined = expectation(description: "guest joined")
        let bothStarted = expectation(description: "started")
        bothStarted.expectedFulfillmentCount = 2
        let gameEnded = expectation(description: "game ended")

        var session: HostGameSession?
        var guestSawEnded = false
        var guestBadMoves = 0
        var leaks = 0
        var hasBidThisDeal = false

        // Guest: scripted remote player (same policy as HostGameSessionTests).
        func guestAct(_ st: GameMsg.State) -> GameMsg.Act? {
            guard st.yourTurn, let ask = st.ask else { return nil }
            if st.info.phase == .Negotiations && st.info.curentBids.isEmpty {
                hasBidThisDeal = false
            }
            switch ask.kind {
            case "bid":
                let bids = ask.bids ?? []
                if !hasBidThisDeal, let real = bids.first(where: { !$0.pas && !$0.miser }) {
                    hasBidThisDeal = true
                    return GameMsg.Act(bid: real)
                }
                return GameMsg.Act(bid: bids.first { $0.pas }!)
            case "contract": return GameMsg.Act(contract: ask.bids!.first!)
            case "vist": return GameMsg.Act(vist: true)
            case "opening": return GameMsg.Act(opening: true)
            case "discard":
                let mine = st.field.filter { $0.hand == 0 && $0.card != nil && !$0.isInPlay && !$0.isPrikup }
                return GameMsg.Act(discard: Array(mine.prefix(2)).map { $0.card! })
            case "play": return GameMsg.Act(play: ask.allowed!.first!)
            case "confirm": return GameMsg.Act(confirm: true)
            default: return nil
            }
        }

        guest.onMessage = { msg in
            switch msg {
            case .welcome:
                break
            case .joined:
                guestJoined.fulfill()
            case .started:
                bothStarted.fulfill()
            case .hostMsg(let data):
                guard let gm = try? data.decode(GameMsg.self), case .state(let st) = gm else { return }
                if st.badMove {
                    guestBadMoves += 1
                }
                if st.ended {
                    guestSawEnded = true
                }
                if let act = guestAct(st), let payload = try? JSONValue.from(GameMsg.act(act)) {
                    guest.send(.send(toSeat: nil, data: payload))
                }
            default:
                break
            }
        }

        host.onMessage = { msg in
            switch msg {
            case .roomCreated(let id):
                roomId = id
                roomCreated.fulfill()
            case .started:
                bothStarted.fulfill()
                gameQueue.async {
                    let game = Game.create()
                    game.calc.limit = 2 // short game over the network
                    game.calc.scores[0].name = "iOS host"
                    game.calc.scores[1].name = "iOS guest"
                    game.calc.scores[2].name = "bot"
                    let s = HostGameSession(
                        game: game,
                        seats: [.bot, .remote, .bot], // own seat bot-driven for automation
                        sendToSeat: { seat, state in
                            // redaction check against the authoritative game state
                            // (runs on gameQueue while the game is quiescent)
                            for pc in state.field
                            where (1...2).contains(pc.hand) && !pc.isInPlay && !pc.isPrikup && pc.card != nil {
                                let absolute = (pc.hand + seat) % 3
                                if !game.deal.hands[absolute].isVisible {
                                    leaks += 1
                                }
                            }
                            if let payload = try? JSONValue.from(GameMsg.state(state)) {
                                host.send(.send(toSeat: seat, data: payload))
                            }
                            if state.ended {
                                gameEnded.fulfill()
                            }
                        },
                        onLocalTurn: {}
                    )
                    session = s
                    do {
                        try s.start()
                    } catch {
                        XCTFail("host session start failed: \(error)")
                    }
                }
            case .playerMsg(let fromSeat, let data):
                gameQueue.async {
                    guard let s = session,
                          let gm = try? data.decode(GameMsg.self),
                          case .act(let act) = gm else { return }
                    do {
                        try s.onRemoteAct(fromSeat, act)
                    } catch {
                        XCTFail("onRemoteAct failed: \(error)")
                    }
                }
            default:
                break
            }
        }

        XCTAssertTrue(host.connect(url), "host must connect")
        XCTAssertTrue(guest.connect(url), "guest must connect")

        let suffix = String(UUID().uuidString.prefix(6))
        host.send(.hello(playerId: "ios-ci-host-\(suffix)", name: "iOS CI Host"))
        guest.send(.hello(playerId: "ios-ci-guest-\(suffix)", name: "iOS CI Guest"))

        let rules = try JSONValue.from(RoomRules(gameRules: GameRules(), limit: 2))
        host.send(.createRoom(name: "iOS-CI-\(suffix)", rules: rules, maxSeats: 3, password: nil))
        wait(for: [roomCreated], timeout: 20)

        guest.send(.join(roomId: try XCTUnwrap(roomId), password: nil))
        wait(for: [guestJoined], timeout: 20)

        host.send(.addBot(seat: nil))
        Thread.sleep(forTimeInterval: 1)
        host.send(.start)
        wait(for: [bothStarted], timeout: 20)

        wait(for: [gameEnded], timeout: 600)
        // let the last host_msg reach the guest
        Thread.sleep(forTimeInterval: 2)

        gameQueue.sync {
            XCTAssertEqual(GamePhase.Ended, session?.game.phase)
            XCTAssertTrue(!(session?.game.calc.gameLog.isEmpty ?? true), "deals were played")
            print("LIVE: deals=\(session?.game.calc.gameLog.count ?? 0) badMoves=\(guestBadMoves)")
        }
        XCTAssertTrue(guestSawEnded, "guest saw the ended state")
        XCTAssertEqual(0, leaks, "no hidden cards may leak over the live relay")

        host.send(.leave)
        guest.send(.leave)
        Thread.sleep(forTimeInterval: 1)
        host.close()
        guest.close()
    }
}
