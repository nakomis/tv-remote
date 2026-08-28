import SwiftUI

struct InputPicker: View {
    @Environment(TVController.self) private var controller

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Input", systemImage: "cable.connector")
                    .font(.headline)
                Spacer()
                Button {
                    Task {
                        await controller.refreshInputs()
                        await controller.refreshCurrentInput()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!controller.state.isConnected)
            }

            if controller.inputs.isEmpty {
                Text(controller.state.isConnected
                     ? "No inputs reported by the TV."
                     : "Connect to see the available inputs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(controller.inputs) { input in
                        InputTile(
                            input: input,
                            isSelected: input.id == controller.currentInputID
                        ) {
                            Task { await controller.switchInput(to: input) }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .opacity(controller.state.isConnected ? 1 : 0.5)
    }
}

private struct InputTile: View {
    let input: TVInput
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: input.symbolName)
                    .font(.title2)
                Text(input.label)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if !input.connected {
                    Text("Nothing attached")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
        .accessibilityLabel("Switch to \(input.label)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
