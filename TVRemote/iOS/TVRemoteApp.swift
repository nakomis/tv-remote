import SwiftUI

@main
struct TVRemoteApp: App {
    @State private var settings: TVSettings
    @State private var controller: TVController

    init() {
        let settings = TVSettings()
        _settings = State(initialValue: settings)
        _controller = State(initialValue: TVController(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environment(settings)
                .environment(controller)
                // The palette is a dark one with no light variant, so the app
                // does not follow the system appearance.
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
