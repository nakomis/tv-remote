import SwiftUI

struct RemoteView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingSettings = false

    private enum Panel {
        case controls, keypad
    }

    @State private var panel: Panel = .controls

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    StatusBadge()
                    switch panel {
                    case .controls:
                        PowerControls()
                        VolumeControl()
                        InputPicker()
                    case .keypad:
                        KeypadView()
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: panel)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("TV")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        panel = panel == .keypad ? .controls : .keypad
                    } label: {
                        Label(
                            panel == .keypad ? "Show the controls" : "Show the keypad",
                            systemImage: panel == .keypad ? "slider.horizontal.3" : "keyboard"
                        )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsForm()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingSettings = false }
                            }
                        }
                }
                .preferredColorScheme(.dark)
            }
        }
        .task {
            await controller.connect()
            controller.startWatchingForTV()
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from the background, the socket is usually dead.
            if phase == .active {
                Task { await controller.reconnectIfNeeded() }
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { controller.lastError != nil },
                set: { if !$0 { controller.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { controller.lastError = nil }
        } message: {
            Text(controller.lastError ?? "")
        }
    }
}
