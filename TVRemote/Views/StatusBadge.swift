import SwiftUI

/// A one-line summary of the connection, with a tap-to-retry affordance when
/// things have gone wrong.
struct StatusBadge: View {
    @Environment(TVController.self) private var controller

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .overlay {
                    if controller.state.isBusy {
                        Circle().stroke(tint.opacity(0.4), lineWidth: 6).scaleEffect(1.8)
                    }
                }
                .animation(.easeInOut, value: controller.state)

            Text(controller.state.describedForHuman)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            if case .failed = controller.state {
                Button("Retry") {
                    Task { await controller.connect() }
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var tint: Color {
        switch controller.state {
        case .connected: .green
        case .connecting, .pairing: .orange
        case .failed: .red
        case .disconnected: .secondary
        }
    }
}
