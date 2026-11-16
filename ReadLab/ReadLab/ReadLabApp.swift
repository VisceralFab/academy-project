import SwiftUI

@main
struct ReadLabApp: App {
    @State private var store: ReadLabStore

    init() {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let suite = "readlab.ui-tests"
            let defaults = UserDefaults(suiteName: suite)!
            if ProcessInfo.processInfo.arguments.contains("--reset-journey") {
                defaults.removePersistentDomain(forName: suite)
            }
            _store = State(initialValue: ReadLabStore(defaults: defaults))
        } else {
            _store = State(initialValue: ReadLabStore())
        }
    }

    var body: some Scene {
        WindowGroup { ContentView(store: store) }
    }
}
