import SwiftUI
import AVFoundation

/// Preview and launch the complete app here, including setup, home, and all three reading paths.
struct ContentView: View {
    @State private var store: ReadLabStore
    @State private var audio: ReadLabAudioController
    @Environment(\.scenePhase) private var scenePhase
    init(store: ReadLabStore? = nil) {
        let store = store ?? ReadLabStore()
        _store = State(initialValue: store)
        _audio = State(initialValue: ReadLabAudioController(defaults: store.defaults))
    }
    var body: some View {
        Group {
            if store.data.hasOnboarded {
                ReadLabHomeView(store: store)
            } else {
                ReadLabOnboarding(store: store)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Button { audio.toggleMusic() } label: {
                Image(systemName: audio.musicIsPaused ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audio.musicIsPaused ? "Play background music" : "Mute background music")
            .accessibilityIdentifier("musicButton")
            .padding(20)
        }
        .environment(\.readLabAudio, audio)
        .onAppear {
            audio.setScene(store.data.hasOnboarded ? .home : .onboarding)
            audio.setActive(scenePhase == .active)
        }
        .onChange(of: store.data.hasOnboarded) { _, finished in audio.setScene(finished ? .home : .onboarding) }
        .onChange(of: scenePhase) { _, phase in audio.setActive(phase == .active) }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.didBecomeInactiveNotification)) { audio.handleDeactivation($0) }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.resumptionRecommendationNotification)) { audio.handleResumption($0) }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { audio.handleRouteChange($0) }
        .environment(\.useDyslexicFont, store.data.preferences.useDyslexicFont)
        .tint(ReadLabStyle.ink)
        .preferredColorScheme(.light)
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                // Report SwiftUI's actual layout, independent of XCTest's physical screen coordinates.
                GeometryReader { geometry in
                    Text(geometry.size.width > geometry.size.height ? "landscape" : "portrait")
                        .font(.system(size: 1))
                        .foregroundStyle(.clear)
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier("appLayoutOrientation")
                        .allowsHitTesting(false)
                }
            }
        }
        .alert("Saved journey", isPresented: Binding(get: { store.storageMessage != nil }, set: { if !$0 { store.storageMessage = nil } })) {
            Button("Continue", role: .cancel) { store.storageMessage = nil }
        } message: { Text(store.storageMessage ?? "") }
    }
}

#Preview("Complete app · landscape", traits: .fixedLayout(width: 1366, height: 1024)) {
    ContentView(store: ReadLabStore(defaults: UserDefaults(suiteName: "readlab.preview.\(UUID())")!))
}

#Preview("Complete app · iPad mini landscape", traits: .fixedLayout(width: 1133, height: 744)) {
    ContentView(store: ReadLabStore(defaults: UserDefaults(suiteName: "readlab.preview.\(UUID())")!))
}
