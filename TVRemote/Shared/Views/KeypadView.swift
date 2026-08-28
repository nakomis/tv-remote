import SwiftUI

/// A key on the remote keypad.
///
/// Keys are data rather than hand-placed views, so adding one is a line in
/// `KeypadView.keys` rather than a layout change. `command` is the button name
/// webOS expects on the pointer input socket — `ENTER`, `UP`, `BACK` and so on.
struct KeypadKey: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    /// The webOS button name sent over the pointer input socket.
    let command: String
    /// Emphasised keys (OK, and later the D-pad centre) are tinted.
    var isPrimary: Bool = false

    static let ok = KeypadKey(
        id: "ok", title: "OK", symbol: "checkmark.circle",
        command: "ENTER", isPrimary: true
    )
}

/// The keypad panel — a second face for the remote, for driving the TV's own
/// on-screen UI rather than its power, volume and inputs.
///
/// Only OK for now. The layout is a grid so the obvious next additions (the
/// D-pad, BACK, HOME, EXIT) drop in without rework.
struct KeypadView: View {
    @Environment(TVController.self) private var controller

    /// Add keys here. The grid and the button styling follow automatically.
    private let keys: [KeypadKey] = [.ok]

    var minimumKeyWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Keypad", systemImage: "keyboard")
                .font(.headline)
                .foregroundStyle(Theme.foreground)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minimumKeyWidth), spacing: 10)],
                spacing: 10
            ) {
                ForEach(keys) { key in
                    KeypadButton(key: key) {
                        Task { await controller.sendKey(key) }
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

private struct KeypadButton: View {
    let key: KeypadKey
    let action: () -> Void

    @Environment(TVController.self) private var controller

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: key.symbol)
                    .font(.title3)
                Text(key.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                key.isPrimary ? Theme.accent.opacity(0.16) : Theme.raised,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(key.isPrimary ? Theme.accent.opacity(0.45) : Theme.border, lineWidth: 1)
            }
            .foregroundStyle(key.isPrimary ? Theme.accent : Theme.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!controller.state.isConnected)
        .accessibilityLabel(key.title)
    }
}
