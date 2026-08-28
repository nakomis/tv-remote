import Foundation
import Observation

/// The app's single source of truth about the television.
///
/// Owns the SSAP connection, keeps the observable state the views render, and
/// turns user intent ("louder", "HDMI 2") into protocol traffic.
@Observable
@MainActor
final class TVController {

    private(set) var state: ConnectionState = .disconnected
    private(set) var volume: Int = 0
    private(set) var isMuted: Bool = false
    private(set) var inputs: [TVInput] = []
    private(set) var currentInputID: String?
    private(set) var isWaking: Bool = false
    private(set) var powerState: TVPowerState?

    /// Surfaced to the UI as a transient banner.
    var lastError: String?

    private let settings: TVSettings
    private let client = SSAPClient()
    private let pointer = PointerInputClient()

    init(settings: TVSettings) {
        self.settings = settings
    }

    // MARK: - Connection

    func connect() async {
        guard !state.isBusy, !state.isConnected else { return }
        guard let url = settings.socketURL else {
            state = .failed("The TV address is not valid.")
            return
        }

        state = .connecting
        let account = KeychainStore.account(forHost: settings.host)

        do {
            let key = try await client.connect(
                to: url,
                clientKey: KeychainStore.loadClientKey(account: account),
                onPairingPrompt: { [weak self] in
                    Task { @MainActor in self?.state = .pairing }
                }
            )
            KeychainStore.saveClientKey(key, account: account)
            state = .connected
            await refreshEverything()
        } catch {
            // A stale key is rejected outright. Drop it so the next attempt
            // falls back to the on-screen prompt rather than failing forever.
            if case SSAPClient.Failure.rejected = error {
                KeychainStore.deleteClientKey(account: account)
            }
            state = .failed(error.localizedDescription)
        }
    }

    func disconnect() async {
        await pointer.disconnect()
        await client.disconnect()
        state = .disconnected
        powerState = nil
    }

    /// Reconnects if the socket has gone away, e.g. after the app was
    /// backgrounded or the TV was turned off by other means.
    func reconnectIfNeeded() async {
        guard await !client.isConnected else { return }
        state = .disconnected
        await connect()
    }

    private func refreshEverything() async {
        await subscribeToPowerState()
        await subscribeToVolume()
        await refreshInputs()
        await refreshCurrentInput()
    }

    // MARK: - Power

    /// Wakes the TV with a magic packet, then waits for it to start answering.
    func powerOn() async {
        guard !isWaking else { return }
        isWaking = true
        defer { isWaking = false }

        let targets: [String]
        do {
            targets = try await WakeOnLAN.wake(
                mac: settings.mac,
                host: settings.host,
                broadcast: settings.broadcast
            )
        } catch {
            lastError = error.localizedDescription
            return
        }

        // The set takes several seconds to bring its network stack up. Retry
        // the connection rather than guessing a single fixed delay.
        let deadline = ContinuousClock.now.advanced(by: Config.wakeTimeout)
        state = .connecting
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .seconds(2))
            await connect()
            if state.isConnected { return }
            if case .pairing = state { return }
        }
        // Name the addresses actually used: a magic packet that goes nowhere
        // reports no error, so the useful diagnostic is where it was sent.
        state = .failed("""
            The TV did not wake. The magic packet for \(settings.mac) went to \(targets.joined(separator: ", ")).
            Check that Settings → General → Devices → TV Management → Mobile TV On is enabled on the TV.
            """)
    }

    func powerOff() async {
        await perform("turning the TV off") {
            try await self.client.request(SSAP.turnOff)
        }
        await disconnect()
    }

    /// Watches the TV's own power state rather than inferring it from the socket.
    ///
    /// webOS keeps the network stack up in states where the panel is dark, so
    /// an open socket alone cannot tell "on" from "screen off" — and when
    /// someone turns the set off with the physical remote, the socket lingers
    /// until the next command fails. Subscribing means the TV tells us.
    private func subscribeToPowerState() async {
        struct PowerPayload: Decodable { let state: String? }

        try? await client.subscribe(SSAP.getPowerState) { [weak self] reply in
            guard let decoded = try? JSONDecoder().decode(PowerPayload.self, from: reply.payload),
                  let reported = decoded.state else { return }
            let power = TVPowerState(reported: reported)
            Task { @MainActor in
                self?.powerState = power
                // The set is on its way down. Drop the connection now so the
                // UI re-enables the On button, rather than showing Connected
                // against a dark television until the next command times out.
                if !power.isAwake {
                    await self?.disconnect()
                }
            }
        }
    }

    // MARK: - Volume

    func volumeUp() async {
        await perform("turning the volume up") {
            try await self.client.request(SSAP.volumeUp)
        }
    }

    func volumeDown() async {
        await perform("turning the volume down") {
            try await self.client.request(SSAP.volumeDown)
        }
    }

    func setVolume(_ level: Int) async {
        let clamped = max(0, min(100, level))
        volume = clamped
        await perform("setting the volume") {
            try await self.client.request(SSAP.setVolume, payload: ["volume": clamped])
        }
    }

    func toggleMute() async {
        let target = !isMuted
        isMuted = target
        await perform("muting the TV") {
            try await self.client.request(SSAP.setMute, payload: ["mute": target])
        }
    }

    private func subscribeToVolume() async {
        struct VolumePayload: Decodable {
            let volume: Int?
            let muted: Bool?
            let volumeStatus: Status?
            struct Status: Decodable {
                let volume: Int?
                let muteStatus: Bool?
            }
        }

        try? await client.subscribe(SSAP.getVolume) { [weak self] reply in
            guard let decoded = try? JSONDecoder().decode(VolumePayload.self, from: reply.payload) else { return }
            // webOS moved these fields into a nested `volumeStatus` object in
            // later releases but still sends the flat ones on some models.
            let level = decoded.volumeStatus?.volume ?? decoded.volume
            let muted = decoded.volumeStatus?.muteStatus ?? decoded.muted
            Task { @MainActor in
                if let level { self?.volume = level }
                if let muted { self?.isMuted = muted }
            }
        }
    }

    // MARK: - Inputs

    func refreshInputs() async {
        struct InputListPayload: Decodable { let devices: [TVInput]? }

        do {
            let reply = try await client.request(SSAP.getExternalInputList)
            let decoded = try JSONDecoder().decode(InputListPayload.self, from: reply.payload)
            inputs = decoded.devices ?? []
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshCurrentInput() async {
        struct ForegroundPayload: Decodable { let appId: String? }

        guard let reply = try? await client.request(SSAP.getForegroundAppInfo),
              let decoded = try? JSONDecoder().decode(ForegroundPayload.self, from: reply.payload),
              let appId = decoded.appId else { return }
        currentInputID = inputs.first { $0.appId == appId }?.id
    }

    func switchInput(to input: TVInput) async {
        currentInputID = input.id
        await perform("switching to \(input.label)") {
            try await self.client.request(SSAP.switchInput, payload: ["inputId": input.id])
        }
    }

    // MARK: - Keypad

    /// Sends a remote-control button press over the pointer input socket.
    ///
    /// The socket is opened lazily on first use and kept for the life of the
    /// SSAP connection: asking for a fresh one per key press works, but adds a
    /// round trip to every button and makes held-down repeats feel awful.
    func sendKey(_ key: KeypadKey) async {
        await perform("sending \(key.title)") {
            try await self.withPointerSocket { pointer in
                try await pointer.send(button: key.command)
            }
        }
    }

    /// Types text into whatever field the TV currently has focused.
    ///
    /// This one is ordinary SSAP, not the pointer socket — different
    /// transport, same `CONTROL_INPUT_TEXT` permission.
    func insertText(_ text: String) async {
        guard !text.isEmpty else { return }
        await perform("typing") {
            try await self.client.request(
                SSAP.insertText,
                payload: ["text": text, "replace": false]
            )
        }
    }

    func deleteCharacters(_ count: Int = 1) async {
        await perform("deleting") {
            try await self.client.request(SSAP.deleteCharacters, payload: ["count": count])
        }
    }

    func sendEnterKey() async {
        await perform("confirming the text") {
            try await self.client.request(SSAP.sendEnterKey)
        }
    }

    /// Runs `body` against a connected pointer socket, opening one if needed
    /// and reopening once if the existing one has died underneath us.
    private func withPointerSocket(
        _ body: (PointerInputClient) async throws -> Void
    ) async throws {
        if await !pointer.isConnected {
            try await pointer.connect(to: client.pointerInputSocketPath())
        }
        do {
            try await body(pointer)
        } catch SSAPClient.Failure.transport, SSAPClient.Failure.notConnected {
            // The socket had gone. Get a fresh path and try once more, since
            // the TV invalidates it across standby.
            try await pointer.connect(to: client.pointerInputSocketPath())
            try await body(pointer)
        }
    }

    // MARK: - Helpers

    private func perform(_ description: String, _ work: () async throws -> Void) async {
        guard state.isConnected else {
            lastError = "Not connected to the TV."
            return
        }
        do {
            try await work()
        } catch {
            lastError = "Failed \(description): \(error.localizedDescription)"
            if case SSAPClient.Failure.transport = error {
                state = .disconnected
            }
        }
    }
}
