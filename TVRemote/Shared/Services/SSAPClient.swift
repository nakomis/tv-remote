import Foundation
import os

/// A connection to a webOS television, speaking SSAP over a WebSocket.
///
/// Messages are JSON objects carrying a `type` (`register`, `request`,
/// `subscribe`), a caller-chosen `id`, a `uri` naming the service, and an
/// optional `payload`. The TV replies asynchronously with the same `id`, so
/// this actor keeps a table of in-flight requests keyed by that id and hands
/// each reply to whoever is waiting for it. Subscriptions differ only in that
/// the TV keeps sending replies with the same id whenever the value changes.
actor SSAPClient {

    enum Failure: LocalizedError {
        case badURL
        case notConnected
        case timedOut(String)
        case rejected(String)
        case pairingDeclined
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .badURL: "The TV address is not a valid host."
            case .notConnected: "Not connected to the TV."
            case .timedOut(let what): "The TV did not respond to \(what) in time."
            case .rejected(let reason): reason
            case .pairingDeclined: "The pairing request was declined on the TV."
            case .transport(let reason): reason
            }
        }
    }

    /// A decoded reply payload. SSAP payloads are heterogeneous, so they are
    /// kept as raw JSON and decoded by the caller that knows the shape.
    struct Reply: Sendable {
        let payload: Data
    }

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private let delegate = TrustLocalTVDelegate()

    private var nextID = 0
    private var pending: [String: CheckedContinuation<Reply, Error>] = [:]
    private var subscriptions: [String: @Sendable (Reply) -> Void] = [:]
    private var receiveLoop: Task<Void, Never>?

    // MARK: - Connection

    /// Opens the socket and registers with the TV.
    ///
    /// - Parameters:
    ///   - clientKey: a key from a previous pairing, if one is stored. When
    ///     present and still valid the TV registers silently; when absent or
    ///     stale it shows the on-screen prompt instead.
    ///   - onPairingPrompt: called if the TV puts its prompt on screen, so the
    ///     UI can tell the user to go and press OK.
    /// - Returns: the client key to store. This may differ from the one passed
    ///   in, and must be persisted.
    func connect(
        to url: URL,
        clientKey: String?,
        onPairingPrompt: @Sendable @escaping () -> Void
    ) async throws -> String {
        await disconnect()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        self.session = session

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        startReceiving()

        return try await register(clientKey: clientKey, onPairingPrompt: onPairingPrompt)
    }

    func disconnect() async {
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        subscriptions.removeAll()
        for (_, continuation) in pending {
            continuation.resume(throwing: Failure.notConnected)
        }
        pending.removeAll()
    }

    var isConnected: Bool { task != nil }

    // MARK: - Registration

    private func register(
        clientKey: String?,
        onPairingPrompt: @Sendable @escaping () -> Void
    ) async throws -> String {
        let id = makeID(prefix: "register")
        let message: [String: Any] = [
            "type": "register",
            "id": id,
            "payload": SSAPHandshake.registerPayload(clientKey: clientKey),
        ]

        // Registration is two-step: an immediate acknowledgement, then a
        // `registered` message carrying the key once the prompt is accepted.
        // Both arrive under the same id, so the acknowledgement is routed to
        // a one-shot handler and the key to the awaiting continuation.
        let promptSignalled = OSAllocatedUnfairLock(initialState: false)
        subscriptions[id] = { reply in
            guard let object = try? JSONSerialization.jsonObject(with: reply.payload) as? [String: Any],
                  object["pairingType"] != nil else { return }
            let alreadySignalled = promptSignalled.withLock { state -> Bool in
                defer { state = true }
                return state
            }
            if !alreadySignalled { onPairingPrompt() }
        }
        defer { subscriptions[id] = nil }

        let frame = try Self.encode(message)
        let reply = try await withTimeout(Config.pairingTimeout, describing: "the pairing request") {
            try await self.send(frame, awaitingReplyTo: id)
        }

        guard let object = try? JSONSerialization.jsonObject(with: reply.payload) as? [String: Any],
              let key = object["client-key"] as? String, !key.isEmpty else {
            throw Failure.pairingDeclined
        }
        return key
    }

    // MARK: - Requests

    @discardableResult
    func request(_ uri: String, payload: [String: Any]? = nil) async throws -> Reply {
        let id = makeID(prefix: "req")
        var message: [String: Any] = ["type": "request", "id": id, "uri": uri]
        if let payload { message["payload"] = payload }
        let frame = try Self.encode(message)
        return try await withTimeout(Config.requestTimeout, describing: uri) {
            try await self.send(frame, awaitingReplyTo: id)
        }
    }

    /// Subscribes to a value and calls `handler` on every update, including
    /// the initial one the TV sends immediately.
    func subscribe(_ uri: String, handler: @Sendable @escaping (Reply) -> Void) async throws {
        let id = makeID(prefix: "sub")
        subscriptions[id] = handler
        let message: [String: Any] = ["type": "subscribe", "id": id, "uri": uri]
        try await transmit(Self.encode(message))
    }

    // MARK: - Plumbing

    private func makeID(prefix: String) -> String {
        nextID += 1
        return "\(prefix)_\(nextID)"
    }

    /// Sends an already-encoded frame and waits for the reply carrying `id`.
    ///
    /// The frame arrives as a `String` rather than a dictionary because
    /// `[String: Any]` is not `Sendable`, and both this and `withTimeout`
    /// hand work to child tasks.
    private func send(_ text: String, awaitingReplyTo id: String) async throws -> Reply {
        try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task {
                do {
                    try await self.transmit(text)
                } catch {
                    self.failPending(id, with: error)
                }
            }
        }
    }

    private nonisolated static func encode(_ message: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: message)
        guard let text = String(data: data, encoding: .utf8) else {
            throw Failure.transport("Could not encode the request.")
        }
        return text
    }

    private func transmit(_ text: String) async throws {
        guard let task else { throw Failure.notConnected }
        do {
            try await task.send(.string(text))
        } catch {
            throw Failure.transport(error.localizedDescription)
        }
    }

    private func failPending(_ id: String, with error: Error) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(throwing: error)
    }

    private func startReceiving() {
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    guard let message = try await self.receiveOne() else { return }
                    await self.handle(message)
                } catch {
                    await self.tearDownAfterTransportFailure(error)
                    return
                }
            }
        }
    }

    private func receiveOne() async throws -> URLSessionWebSocketTask.Message? {
        guard let task else { return nil }
        return try await task.receive()
    }

    private func tearDownAfterTransportFailure(_ error: Error) {
        for (_, continuation) in pending {
            continuation.resume(throwing: Failure.transport(error.localizedDescription))
        }
        pending.removeAll()
        subscriptions.removeAll()
        task = nil
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let raw): data = raw
        @unknown default: return
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = object["id"] as? String else { return }

        let type = object["type"] as? String ?? "response"
        let payloadObject = object["payload"] as? [String: Any] ?? [:]
        let payloadData = (try? JSONSerialization.data(withJSONObject: payloadObject)) ?? Data("{}".utf8)
        let reply = Reply(payload: payloadData)

        if type == "error" {
            let reason = object["error"] as? String ?? "The TV rejected the request."
            failPending(id, with: Failure.rejected(reason))
            return
        }

        // `returnValue: false` is how SSAP signals a refusal inside an
        // otherwise well-formed response.
        if let returnValue = payloadObject["returnValue"] as? Bool, returnValue == false,
           pending[id] != nil {
            let reason = payloadObject["errorText"] as? String ?? "The TV rejected the request."
            failPending(id, with: Failure.rejected(reason))
            return
        }

        subscriptions[id]?(reply)

        // The registration acknowledgement carries no client-key; only the
        // later `registered` message does. Leave the continuation waiting.
        if type == "response", payloadObject["pairingType"] != nil, payloadObject["client-key"] == nil {
            return
        }

        if let continuation = pending.removeValue(forKey: id) {
            continuation.resume(returning: reply)
        }
    }

    private func withTimeout<T: Sendable>(
        _ duration: Duration,
        describing what: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw Failure.timedOut(what)
            }
            guard let result = try await group.next() else {
                throw Failure.timedOut(what)
            }
            group.cancelAll()
            return result
        }
    }
}

/// Accepts the television's self-signed certificate when connecting over
/// `wss://`.
///
/// webOS ships a certificate issued to itself, so the system trust evaluation
/// always fails. This is only reached for the TLS port, on a LAN address the
/// user configured by hand; the alternative is not encryption but no
/// connection at all.
private final class TrustLocalTVDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
