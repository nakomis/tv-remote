import SwiftUI

struct SettingsView: View {
    @Environment(Settings.self) private var settings
    @Environment(TVController.self) private var controller
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    LabeledContent("Address") {
                        TextField(Config.defaultHost, text: $settings.host)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("MAC") {
                        TextField(Config.defaultMAC, text: $settings.mac)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Broadcast") {
                        TextField(Config.defaultBroadcast, text: $settings.broadcast)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Television")
                } footer: {
                    Text("The MAC address is the target of the Wake-on-LAN packet that turns the TV on; the broadcast address is where that packet is sent, since a sleeping TV has no address of its own.")
                }

                Section {
                    Toggle("Use TLS", isOn: $settings.useTLS)
                } footer: {
                    Text("On uses wss:// on port \(Config.tlsPort) with the TV's self-signed certificate; off uses ws:// on port \(Config.plainPort). webOS 23 only answers on the TLS port — plaintext accepts the connection and then drops it — so leave this on unless the TV is an older model.")
                }

                Section {
                    Button("Reconnect") {
                        Task {
                            await controller.disconnect()
                            await controller.connect()
                        }
                    }
                    Button("Forget pairing", role: .destructive) {
                        KeychainStore.deleteClientKey(account: settings.host)
                        Task { await controller.disconnect() }
                    }
                } footer: {
                    Text("Forgetting the pairing makes the TV show its \"allow this device?\" prompt again on the next connection.")
                }

                Section {
                    Button("Restore defaults") {
                        settings.resetToDefaults()
                    }
                } footer: {
                    Text("Restores the values compiled into Config.swift.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let settings = Settings()
    return SettingsView()
        .environment(settings)
        .environment(TVController(settings: settings))
}
