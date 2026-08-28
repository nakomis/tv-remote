import SwiftUI

struct PowerControls: View {
    @Environment(TVController.self) private var controller

    var body: some View {
        HStack(spacing: 16) {
            PowerButton(
                title: "On",
                symbol: "power",
                tint: .green,
                isBusy: controller.isWaking,
                isEnabled: !controller.state.isConnected && !controller.isWaking
            ) {
                Task { await controller.powerOn() }
            }

            PowerButton(
                title: "Off",
                symbol: "power",
                tint: .red,
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
    let symbol: String
    let tint: Color
    let isBusy: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .opacity(isBusy ? 0 : 1)
                    if isBusy { ProgressView().controlSize(.large) }
                }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(tint.opacity(isEnabled ? 0.15 : 0.06), in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(isEnabled ? tint : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Turn TV \(title.lowercased())")
    }
}
