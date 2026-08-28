import SwiftUI

/// A key on the remote keypad.
///
/// `command` is the button name webOS expects on the pointer input socket.
struct KeypadKey: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    /// The webOS button name sent over the pointer input socket.
    let command: String

    static let up = KeypadKey(id: "up", title: "Up", symbol: "chevron.up", command: "UP")
    static let down = KeypadKey(id: "down", title: "Down", symbol: "chevron.down", command: "DOWN")
    static let left = KeypadKey(id: "left", title: "Left", symbol: "chevron.left", command: "LEFT")
    static let right = KeypadKey(id: "right", title: "Right", symbol: "chevron.right", command: "RIGHT")
    static let ok = KeypadKey(id: "ok", title: "OK", symbol: "circle", command: "ENTER")

    static let back = KeypadKey(id: "back", title: "Back", symbol: "arrow.uturn.backward", command: "BACK")
    static let home = KeypadKey(id: "home", title: "Home", symbol: "house", command: "HOME")
    static let exit = KeypadKey(id: "exit", title: "Exit", symbol: "xmark", command: "EXIT")
    static let menu = KeypadKey(id: "menu", title: "Menu", symbol: "list.bullet", command: "MENU")
    static let info = KeypadKey(id: "info", title: "Info", symbol: "info.circle", command: "INFO")

    /// The row of secondary keys. Add to this and the grid follows.
    static let secondary: [KeypadKey] = [.back, .home, .menu, .info, .exit]
}

/// The keypad panel — for driving the TV's own on-screen UI.
///
/// The D-pad is laid out as a cross rather than a grid because that is what a
/// remote looks like, and muscle memory matters more here than tidy code.
struct KeypadView: View {
    @Environment(TVController.self) private var controller

    @State private var typing = ""
    @FocusState private var typingFocused: Bool

    var compact = false

    private var arrowSize: CGFloat { compact ? 54 : 66 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Keypad", systemImage: "keyboard")
                .font(.headline)
                .foregroundStyle(Theme.foreground)

            dpad
                .frame(maxWidth: .infinity)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: compact ? 56 : 68), spacing: 8)],
                spacing: 8
            ) {
                ForEach(KeypadKey.secondary) { key in
                    KeypadButton(key: key, style: .secondary, size: nil) {
                        Task { await controller.sendKey(key) }
                    }
                }
            }

            textEntry
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.border, lineWidth: 1)
        }
        .opacity(controller.state.isConnected ? 1 : 0.45)
    }

    private var dpad: some View {
        VStack(spacing: 6) {
            arrow(.up)
            HStack(spacing: 6) {
                arrow(.left)
                KeypadButton(key: .ok, style: .primary, size: arrowSize) {
                    Task { await controller.sendKey(.ok) }
                }
                arrow(.right)
            }
            arrow(.down)
        }
    }

    private func arrow(_ key: KeypadKey) -> some View {
        KeypadButton(key: key, style: .arrow, size: arrowSize) {
            Task { await controller.sendKey(key) }
        }
    }

    private var textEntry: some View {
        HStack(spacing: 8) {
            TextField("Type on the TV…", text: $typing)
                .textFieldStyle(.plain)
                .focused($typingFocused)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10))
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(typing.isEmpty ? Theme.ring : Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(typing.isEmpty || !controller.state.isConnected)
            .accessibilityLabel("Send the text to the TV")
        }
        .disabled(!controller.state.isConnected)
    }

    private func send() {
        let text = typing
        guard !text.isEmpty else { return }
        typing = ""
        Task {
            await controller.insertText(text)
            await controller.sendEnterKey()
        }
    }
}

private struct KeypadButton: View {
    enum Style { case primary, arrow, secondary }

    let key: KeypadKey
    let style: Style
    /// Fixed square size for the D-pad; `nil` lets the grid size it.
    let size: CGFloat?
    let action: () -> Void

    @Environment(TVController.self) private var controller

    var body: some View {
        Button(action: action) {
            Group {
                switch style {
                case .primary:
                    Text(key.title).font(.subheadline.weight(.bold))
                case .arrow:
                    Image(systemName: key.symbol).font(.title3.weight(.semibold))
                case .secondary:
                    VStack(spacing: 3) {
                        Image(systemName: key.symbol).font(.footnote)
                        Text(key.title).font(.caption2)
                    }
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: size == nil ? .infinity : nil)
            .padding(.vertical, size == nil ? 8 : 0)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(border, lineWidth: style == .primary ? 1.5 : 1)
            }
            .foregroundStyle(style == .primary ? Theme.accent : Theme.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!controller.state.isConnected)
        .accessibilityLabel(key.title)
    }

    private var background: Color {
        style == .primary ? Theme.accent.opacity(0.16) : Theme.raised
    }

    private var border: Color {
        style == .primary ? Theme.accent.opacity(0.5) : Theme.border
    }
}
