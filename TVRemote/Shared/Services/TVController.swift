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

    /// Surfaced to the UI as a transient banner.
    var lastError: String?

    private let settings: TVSettings
    private let client = SSAPClient()

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
        let account = settings.host

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
        await client.disconnect()
        state = .disconnected
    }

    /// Reconnects if the socket has gone away, e.g. after the app was
    /// backgrounded or the TV was turned off by other means.
    func reconnectIfNeeded() async {
        guard await !client.isConnected else { return }
        state = .disconnected
        await connect()
    }

    private func refreshEverything() async {
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

        do {
            try await WakeOnLAN.wake(mac: settings.mac, broadcast: settings.broadcast)
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
        state = .failed("The TV did not wake. Check that Settings → General → Devices → TV Management → Mobile TV On is enabled.")
    }

    func powerOff() async {
        await perform("turning the TV off") {
            try await self.client.request(SSAP.turnOff)
        }
        await disconnect()
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
