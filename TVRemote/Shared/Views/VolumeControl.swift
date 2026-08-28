import SwiftUI

struct VolumeControl: View {
    @Environment(TVController.self) private var controller

    /// Held while the user is dragging so incoming subscription updates do
    /// not yank the thumb out from under their finger.
    @State private var scrubbing: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Volume", systemImage: controller.isMuted ? "speaker.slash" : "speaker.wave.2")
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Text("\(displayedVolume)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.mutedForeground)
            }

            Slider(
                value: Binding(
                    get: { scrubbing ?? Double(controller.volume) },
                    set: { scrubbing = $0 }
                ),
                in: 0...100,
                step: 1,
                onEditingChanged: { editing in
                    guard !editing, let value = scrubbing else { return }
                    scrubbing = nil
                    Task { await controller.setVolume(Int(value.rounded())) }
                }
            )
            .tint(Theme.accent)
            .disabled(!controller.state.isConnected)

            HStack(spacing: 10) {
                stepButton("minus", label: "Volume down") {
                    Task { await controller.volumeDown() }
                }
                stepButton("plus", label: "Volume up") {
                    Task { await controller.volumeUp() }
                }
                Button {
                    Task { await controller.toggleMute() }
                } label: {
                    Label(
                        controller.isMuted ? "Unmute" : "Mute",
                        systemImage: controller.isMuted ? "speaker.slash.fill" : "speaker.fill"
                    )
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        controller.isMuted ? Theme.destructive.opacity(0.16) : Theme.raised,
                        in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    )
                    .foregroundStyle(controller.isMuted ? Theme.destructive : Theme.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!controller.state.isConnected)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.border, lineWidth: 1)
        }
        .opacity(controller.state.isConnected ? 1 : 0.45)
    }

    private var displayedVolume: Int {
        Int((scrubbing ?? Double(controller.volume)).rounded())
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .foregroundStyle(Theme.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!controller.state.isConnected)
        .accessibilityLabel(label)
    }
}
