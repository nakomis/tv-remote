import SwiftUI

struct PowerControls: View {
    @Environment(TVController.self) private var controller

    var body: some View {
        HStack(spacing: 12) {
            PowerButton(
                title: "On",
                tint: Theme.positive,
                isBusy: controller.isWaking,
                isEnabled: !controller.state.isConnected && !controller.isWaking
            ) {
                Task { await controller.powerOn() }
            }

            PowerButton(
                title: "Off",
                tint: Theme.destructive,
                isBusy: false,
                isEnabled: controller.state.isConnected
            ) {
                Task { await controller.powerOff() }
            }
        }
    }
}

struct PowerButton: View {
    let title: String
    let tint: Color
    let isBusy: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: "power")
                        .font(.system(size: 24, weight: .semibold))
                        .opacity(isBusy ? 0 : 1)
                    if isBusy { ProgressView().controlSize(.small).tint(tint) }
                }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                (isEnabled ? tint.opacity(0.16) : Theme.raised),
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(isEnabled ? tint.opacity(0.45) : Theme.border, lineWidth: 1)
            }
            .foregroundStyle(isEnabled ? tint : Theme.ring)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Turn TV \(title.lowercased())")
    }
}
