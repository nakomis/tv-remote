import SwiftUI

/// The popover behind the menu bar icon.
///
/// Narrower and tighter than the iOS layout — a menu bar panel that stretches
/// halfway down the screen defeats the point of being one click away.
///
/// It shows one of two faces: the functional controls (power, volume, input),
/// or the keypad for driving the TV's own on-screen UI. The header is shared
/// between them so the panel swaps underneath a fixed set of controls.
struct MenuBarRemoteView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.openSettings) private var openSettings

    private enum Panel {
        case controls, keypad
    }

    @State private var panel: Panel = .controls

    var body: some View {
        VStack(spacing: 14) {
            header

            switch panel {
            case .controls:
                PowerControls()
                VolumeControl()
                InputPicker(minimumTileWidth: 110)
            case .keypad:
                KeypadView()
            }

            if let error = controller.lastError {
                errorBanner(error)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Theme.background)
        .animation(.easeInOut(duration: 0.18), value: panel)
        .task { await controller.connect() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Label("TV", systemImage: "tv")
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)

                Spacer()

                Button {
                    panel = panel == .keypad ? .controls : .keypad
                } label: {
                    Image(systemName: panel == .keypad ? "slider.horizontal.3" : "keyboard")
                        .foregroundStyle(panel == .keypad ? Theme.accent : Theme.mutedForeground)
                }
                .buttonStyle(.plain)
                .help(panel == .keypad ? "Show the controls" : "Show the keypad")
                .accessibilityLabel(panel == .keypad ? "Show the controls" : "Show the keypad")

                Button {
                    showSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Theme.mutedForeground)
                }
                .buttonStyle(.plain)
                .help("Settings")
                .accessibilityLabel("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power.circle")
                        .foregroundStyle(Theme.mutedForeground)
                }
                .buttonStyle(.plain)
                .help("Quit TV Remote")
                .accessibilityLabel("Quit TV Remote")
            }

            StatusBadge()
        }
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.destructive)
            Text(error)
                .font(.caption)
                .foregroundStyle(Theme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                controller.lastError = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.ring)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(10)
        .background(
            Theme.destructive.opacity(0.12),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
        )
    }

    /// Opens the Settings window *and brings it to the front*.
    ///
    /// The app is an agent (`LSUIElement`), so it is never the active
    /// application. `openSettings()` alone creates the window behind whatever
    /// the user is actually looking at, which reads exactly like the button
    /// being dead. Activating first is what makes it appear.
    private func showSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openSettings()
    }
}
