import Foundation
import PrefEngine

enum ConnState {
    case disconnected, connecting, connected
}

/// Thin WebSocket wrapper around the pref-server protocol (URLSession WS).
/// Incoming messages and state changes are delivered on the main queue.
final class LobbyClient: NSObject, URLSessionWebSocketDelegate {

    static let defaultURL = "wss://preferansmaster.com/ws"

    private let url: URL
    private var session: URLSession!
    private var ws: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    private var helloOnOpen: ClientMsg?

    var onState: ((ConnState) -> Void)?
    var onMessage: ((ServerMsg) -> Void)?

    private(set) var state = ConnState.disconnected {
        didSet {
            let s = state
            DispatchQueue.main.async { [weak self] in
                self?.onState?(s)
            }
        }
    }

    init(url: String = LobbyClient.defaultURL) {
        self.url = URL(string: url)!
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func connect(playerId: String, name: String) {
        guard state == .disconnected else { return }
        state = .connecting
        helloOnOpen = .hello(playerId: playerId, name: name)
        let task = session.webSocketTask(with: url)
        ws = task
        receiveLoop(task)
        task.resume()
    }

    @discardableResult
    func send(_ msg: ClientMsg) -> Bool {
        guard let ws = ws else { return false }
        guard let text = try? WireJSON.encodeToString(msg) else { return false }
        ws.send(.string(text)) { error in
            if let error = error {
                NSLog("PrefNet: ws send failed: %@", "\(error)")
            }
        }
        return true
    }

    func disconnect() {
        pingTask?.cancel()
        pingTask = nil
        ws?.cancel(with: .normalClosure, reason: nil)
        ws = nil
        state = .disconnected
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self = self, task === self.ws else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handle(text)
                } else if case .data(let data) = message, let text = String(data: data, encoding: .utf8) {
                    self.handle(text)
                }
                self.receiveLoop(task)
            case .failure(let error):
                NSLog("PrefNet: ws failure: %@", "\(error)")
                self.ws = nil
                self.state = .disconnected
            }
        }
    }

    private func handle(_ text: String) {
        do {
            let msg = try WireJSON.decodeFromString(ServerMsg.self, text)
            DispatchQueue.main.async { [weak self] in
                self?.onMessage?(msg)
            }
        } catch {
            NSLog("PrefNet: unparseable server message: %@", text)
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        state = .connected
        if let hello = helloOnOpen {
            send(hello)
        }
        // keepalive ping every ~25s (OkHttp pingInterval equivalent)
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                guard let self = self, let ws = self.ws else { return }
                ws.sendPing { _ in }
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if webSocketTask === ws {
            ws = nil
            state = .disconnected
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if task === ws {
            ws = nil
            state = .disconnected
        }
    }
}
