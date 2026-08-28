import SwiftUI

/// The settings form, shared by both platforms.
///
/// iOS presents it as a sheet inside a `NavigationStack`; macOS puts it in its
/// own window from the menu bar, so the chrome around it belongs to each
/// platform's shell rather than here.
struct SettingsForm: View {
    @Environment(TVSettings.self) private var settings
    @Environment(TVController.self) private var controller

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                field("Address", text: $settings.host, prompt: Config.defaultHost)
                field("MAC", text: $settings.mac, prompt: Config.defaultMAC)
                field("Broadcast", text: $settings.broadcast, prompt: Config.defaultBroadcast)
            } header: {
                Text("Television")
            } footer: {
                Text("The MAC address is the target of the Wake-on-LAN packet that turns the TV on; the broadcast address is where that packet is sent, since a sleeping TV has no address of its own.")
                    .foregroundStyle(Theme.mutedForeground)
            }

            Section {
                Toggle("Use TLS", isOn: $settings.useTLS)
            } footer: {
                Text("On uses wss:// on port \(Config.tlsPort) with the TV's self-signed certificate; off uses ws:// on port \(Config.plainPort). webOS 23 only answers on the TLS port — plaintext accepts the connection and then drops it — so leave this on unless the TV is an older model.")
                    .foregroundStyle(Theme.mutedForeground)
            }

            Section {
                Button("Reconnect") {
                    Task {
                        await controller.disconnect()
                        await controller.connect()
                    }
                }
                Button("Forget pairing", role: .destructive) {
                    KeychainStore.deleteClientKey(account: KeychainStore.account(forHost: settings.host))
                    Task { await controller.disconnect() }
                }
            } footer: {
                Text("Forgetting the pairing makes the TV show its \"allow this device?\" prompt again on the next connection.")
                    .foregroundStyle(Theme.mutedForeground)
            }

            Section {
                Button("Restore defaults") { settings.resetToDefaults() }
            } footer: {
                Text("Restores the values compiled into Config.swift.")
                    .foregroundStyle(Theme.mutedForeground)
            }
        }
        .formStyle(.grouped)
        .tint(Theme.accent)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        LabeledContent(label) {
            TextField(prompt, text: text)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.numbersAndPunctuation)
                #endif
        }
    }
}
