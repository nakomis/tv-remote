import SwiftUI

/// A one-line summary of the connection, with a tap-to-retry affordance when
/// things have gone wrong.
struct StatusBadge: View {
    @Environment(TVController.self) private var controller

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)
                .overlay {
                    if controller.state.isBusy {
                        Circle().stroke(tint.opacity(0.35), lineWidth: 5).scaleEffect(1.9)
                    }
                }
                .animation(.easeInOut, value: controller.state)

            Text(controller.state.describedForHuman)
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if case .failed = controller.state {
                Button("Retry") { Task { await controller.connect() } }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.border, lineWidth: 1)
        }
    }

    private var tint: Color {
        switch controller.state {
        case .connected: Theme.positive
        case .connecting, .pairing: Theme.accent
        case .failed: Theme.destructive
        case .disconnected: Theme.ring
        }
    }
}
