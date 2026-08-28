import SwiftUI

struct InputPicker: View {
    @Environment(TVController.self) private var controller

    /// The tile width the grid adapts around. The menu bar popover is
    /// narrower than a phone, so it asks for something tighter.
    var minimumTileWidth: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Input", systemImage: "cable.connector")
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                Spacer()
                Button {
                    Task {
                        await controller.refreshInputs()
                        await controller.refreshCurrentInput()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(!controller.state.isConnected)
                .accessibilityLabel("Refresh the input list")
            }

            if controller.inputs.isEmpty {
                Text(controller.state.isConnected
                     ? "No inputs reported by the TV."
                     : "Connect to see the available inputs.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: minimumTileWidth), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(controller.inputs) { input in
                        InputTile(input: input, isSelected: input.id == controller.currentInputID) {
                            Task { await controller.switchInput(to: input) }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.border, lineWidth: 1)
        }
        .opacity(controller.state.isConnected ? 1 : 0.45)
    }
}

private struct InputTile: View {
    let input: TVInput
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: input.symbolName)
                    .font(.title3)
                Text(input.label)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if !input.connected {
                    Text("Nothing attached")
                        .font(.caption2)
                        .foregroundStyle(Theme.ring)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                isSelected ? Theme.accent.opacity(0.18) : Theme.raised,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 1.5 : 1)
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch to \(input.label)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
