import SwiftUI

/// The popover behind the menu bar icon.
///
/// Narrower and tighter than the iOS layout — a menu bar panel that stretches
/// halfway down the screen defeats the point of being one click away.
struct MenuBarRemoteView: View {
    @Environment(TVController.self) private var controller
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("TV", systemImage: "tv")
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Theme.mutedForeground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power.circle")
                        .foregroundStyle(Theme.mutedForeground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quit TV Remote")
            }

            StatusBadge()
            PowerControls()
            VolumeControl()
            InputPicker(minimumTileWidth: 110)

            if let error = controller.lastError {
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
        }
        .padding(14)
        .frame(width: 320)
        .background(Theme.background)
        .task { await controller.connect() }
    }
}
