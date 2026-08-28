import SwiftUI

@main
struct TVRemoteMacApp: App {
    @State private var settings: TVSettings
    @State private var controller: TVController

    init() {
        let settings = TVSettings()
        _settings = State(initialValue: settings)
        _controller = State(initialValue: TVController(settings: settings))
    }

    var body: some Scene {
        // A remote belongs in the menu bar, not in a window you have to find.
        // `.window` style rather than `.menu` because the content is a laid-out
        // panel with a slider and a grid, not a list of menu items.
        MenuBarExtra("TV Remote", systemImage: "tv") {
            MenuBarRemoteView()
                .environment(settings)
                .environment(controller)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .menuBarExtraStyle(.window)

        // SwiftUI's `Settings` scene — hence our own settings type being
        // called `TVSettings`, since a same-named class silently shadows
        // this and the error it produces points nowhere near the cause.
        Settings {
            SettingsForm()
                .environment(settings)
                .environment(controller)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .frame(width: 460, height: 460)
        }
    }
}
