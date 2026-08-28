import SwiftUI

struct VolumeControl: View {
    @Environment(TVController.self) private var controller

    /// Held while the user is dragging so incoming subscription updates do
    /// not yank the thumb out from under their finger.
    @State private var scrubbing: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Volume", systemImage: "speaker.wave.2")
                    .font(.headline)
                Spacer()
                Text("\(displayedVolume)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
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
            .disabled(!controller.state.isConnected)

            HStack(spacing: 12) {
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        (controller.isMuted ? Color.orange : Color.secondary).opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(controller.isMuted ? Color.orange : Color.primary)
                .disabled(!controller.state.isConnected)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .opacity(controller.state.isConnected ? 1 : 0.5)
    }

    private var displayedVolume: Int {
        Int((scrubbing ?? Double(controller.volume)).rounded())
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .disabled(!controller.state.isConnected)
        .accessibilityLabel(label)
    }
}
