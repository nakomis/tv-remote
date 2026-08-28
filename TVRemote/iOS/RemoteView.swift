import SwiftUI

struct RemoteView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    StatusBadge()
                    PowerControls()
                    VolumeControl()
                    InputPicker()
                }
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
        .task { await controller.connect() }
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
