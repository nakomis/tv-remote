import Foundation

/// The television's *second* WebSocket — the one that carries button presses.
///
/// SSAP itself does not accept remote-control buttons. Instead you ask it for
/// `ssap://com.webos.service.networkinput/getPointerInputSocket`, and it hands
/// back a URL for a separate socket that speaks a completely different, much
/// simpler protocol: newline-delimited `key:value` pairs terminated by a blank
/// line, with no ids, no replies, and no acknowledgement of any kind.
///
///     type:button
///     name:ENTER
///     <blank line>
///
/// Because nothing is acknowledged, a failure here is silent by construction —
/// the send succeeds whether or not the TV did anything. The only real signal
/// is the socket closing.
actor PointerInputClient {

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private let delegate = TrustLocalTVDelegate()

    var isConnected: Bool { task != nil }

    func connect(to url: URL) throws {
        disconnect()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        self.session = session

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    /// Presses and releases a button — `ENTER`, `UP`, `BACK`, `HOME`, and so on.
    func send(button name: String) async throws {
        try await send(frame: "type:button\nname:\(name)\n\n")
    }

    /// Moves the on-screen pointer. `down` is 1 while dragging.
    func move(dx: Int, dy: Int, down: Bool = false) async throws {
        try await send(frame: "type:move\ndx:\(dx)\ndy:\(dy)\ndown:\(down ? 1 : 0)\n\n")
    }

    /// Clicks at the pointer's current position.
    func click() async throws {
        try await send(frame: "type:click\n\n")
    }

    private func send(frame: String) async throws {
        guard let task else { throw SSAPClient.Failure.notConnected }
        do {
            try await task.send(.string(frame))
        } catch {
            // The socket is gone; drop it so the next call reconnects rather
            // than sending into a dead connection forever.
            disconnect()
            throw SSAPClient.Failure.transport(error.localizedDescription)
        }
    }
}
