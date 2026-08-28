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

            Text(statusText)
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

    /// "Connected", or "Connected · screen off" when the TV has something to
    /// add. The note only ever appears while genuinely connected.
    private var statusText: String {
        guard controller.state.isConnected, let note = controller.powerState?.note else {
            return controller.state.describedForHuman
        }
        return "\(controller.state.describedForHuman) · \(note)"
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
