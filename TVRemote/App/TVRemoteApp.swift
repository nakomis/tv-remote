import SwiftUI

@main
struct TVRemoteApp: App {
    @State private var settings = Settings()
    @State private var controller: TVController

    init() {
        let settings = Settings()
        _settings = State(initialValue: settings)
        _controller = State(initialValue: TVController(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environment(settings)
                .environment(controller)
        }
    }
}
