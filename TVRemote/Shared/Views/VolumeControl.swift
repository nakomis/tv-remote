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

            volumeSlider
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


    private var level: Binding<Double> {
        Binding(
            get: { scrubbing ?? Double(controller.volume) },
            set: { scrubbing = $0 }
        )
    }

    /// Commits the value once the drag ends, rather than on every frame —
    /// setVolume makes webOS flash its on-screen volume bar.
    private func commit(_ editing: Bool) {
        guard !editing, let value = scrubbing else { return }
        scrubbing = nil
        Task { await controller.setVolume(Int(value.rounded())) }
    }

    /// Tick marks need `SliderTick`, which is iOS 26 / macOS 26 only, while
    /// this project targets iOS 17 / macOS 14 — hence the availability check
    /// rather than simply using it.
    ///
    /// The ticked initialiser requires a `label:` (it has no default) and
    /// wants `ticks:` *before* `onEditingChanged:`. The label is hidden here
    /// because the row above already says "Volume". Omitting `step:` keeps
    /// the slider continuous —
    /// a discrete slider draws one tick per step on macOS, which at
    /// `0...100, step: 1` is 101 of them and reads as a smudge.
    @ViewBuilder
    private var volumeSlider: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Slider(
                value: level,
                in: 0...100,
                label: { Text("Volume") },
                ticks: {
                    SliderTick("0", 0)
                    SliderTick("20", 20)
                    SliderTick("40", 40)
                    SliderTick("50", 60)
                    SliderTick("80", 80)
                    SliderTick("100", 100)
                },
                onEditingChanged: commit
            )
            .labelsHidden()
        } else {
            Slider(value: level, in: 0...100, onEditingChanged: commit)
        }
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
