import SwiftUI

/// Preview and launch the complete app here, including setup, home, and all three reading paths.
struct ContentView: View {
    @State private var store: ReadLabStore
    init(store: ReadLabStore? = nil) { _store = State(initialValue: store ?? ReadLabStore()) }
    var body: some View {
        Group {
            if store.data.hasOnboarded {
                ReadLabHomeView(store: store)
            } else {
                ReadingSupportOnboarding(store: store)
            }
        }
        .environment(\.useDyslexicFont, store.data.preferences.useDyslexicFont)
        .tint(ReadLabStyle.ink)
        .preferredColorScheme(.light)
        .alert("Saved journey", isPresented: Binding(get: { store.storageMessage != nil }, set: { if !$0 { store.storageMessage = nil } })) {
            Button("Continue", role: .cancel) { store.storageMessage = nil }
        } message: { Text(store.storageMessage ?? "") }
    }
}

#Preview("Complete app · landscape", traits: .fixedLayout(width: 1366, height: 1024)) {
    ContentView(store: ReadLabStore(defaults: UserDefaults(suiteName: "readlab.preview.\(UUID())")!))
}

#Preview("Complete app · portrait", traits: .fixedLayout(width: 820, height: 1180)) {
    ContentView(store: ReadLabStore(defaults: UserDefaults(suiteName: "readlab.preview.\(UUID())")!))
}
