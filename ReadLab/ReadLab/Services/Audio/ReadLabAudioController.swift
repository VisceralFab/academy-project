import AVFoundation
import Observation
import SwiftUI

enum ReadLabAudioScene: Equatable { case onboarding, home, practice }

enum ReadLabSound: String, CaseIterable {
    case onboarding = "Onboard music", home = "Background home music"
    case elephantMascot = "Elephant 2"
    case parrotMascot = "Parrot 2"
    case monkeyMascot = "Monkey 2"
    case correct = "Correct sound"

    /// Edit these percentages (0–100) to set the playback volume of each file.
    private var volumePercent: Float {
        switch self {
        case .onboarding: 20
        case .home: 20
        case .correct: 45
        case .elephantMascot: 80
        case .parrotMascot: 80
        case .monkeyMascot: 80
        }
    }

    var volume: Float { min(100, max(0, volumePercent)) / 100 }

    var url: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "mp3")
            ?? Bundle.main.url(forResource: rawValue, withExtension: "mp3", subdirectory: "Sounds")
    }

    static func animal(for path: ReadingPath) -> Self {
        switch path {
        case .hearing: .elephantMascot
        case .words: .parrotMascot
        case .stories: .monkeyMascot
        }
    }
}

/// One owner for decorative audio. Exercises own their speech audio session independently.
@MainActor @Observable
final class ReadLabAudioController {
    var musicEnabled: Bool {
        didSet { defaults.set(musicEnabled, forKey: "readlab.musicEnabled"); refreshMusic() }
    }
    var effectsEnabled: Bool {
        didSet {
            defaults.set(effectsEnabled, forKey: "readlab.effectsEnabled")
            if !effectsEnabled { effectPlayer?.stop() }
        }
    }
    private(set) var scene: ReadLabAudioScene = .onboarding
    private(set) var isActive = false
    private(set) var playingMusic: ReadLabSound?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var musicPlayer: AVAudioPlayer?
    @ObservationIgnored private var effectPlayer: AVAudioPlayer?
    @ObservationIgnored private var transition: Task<Void, Never>?
    private var interrupted = false
    private var routePaused = false
    @ObservationIgnored private let previews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        musicEnabled = defaults.object(forKey: "readlab.musicEnabled") as? Bool ?? true
        effectsEnabled = defaults.object(forKey: "readlab.effectsEnabled") as? Bool ?? true
    }

    func setScene(_ scene: ReadLabAudioScene) {
        guard self.scene != scene else { return }
        self.scene = scene
        routePaused = false
        // Stop immediately before speech input can start, including any still-playing mascot.
        if scene == .practice { effectPlayer?.stop() }
        refreshMusic()
    }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        if !active { effectPlayer?.stop() }
        refreshMusic()
    }

    func playAnimal(for path: ReadingPath) {
        guard effectsEnabled, isActive, !interrupted, scene != .practice, !previews else { return }
        let sound = ReadLabSound.animal(for: path)
        guard let url = sound.url else { return }
        effectPlayer?.stop()
        do {
            try activateAmbientAudio()
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sound.volume
            effectPlayer = player
            player.play()
        } catch { /* Mascot interaction remains available without audio output. */ }
    }

    func handleDeactivation(_ notification: Notification) {
        guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
              context.source == .system else { return }
        setInterrupted(true)
    }

    func handleResumption(_ notification: Notification) {
        guard let context = notification.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext else { return }
        setInterrupted(context.recommendation != .shouldResume)
    }

    func setInterrupted(_ value: Bool) {
        interrupted = value
        if value { effectPlayer?.stop() }
        refreshMusic()
    }

    func handleRouteChange(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        // Unplugging headphones should not unexpectedly move the music to the loudspeaker.
        routePaused = true
        effectPlayer?.stop()
        refreshMusic()
    }

    func toggleMusic() {
        if routePaused || interrupted { routePaused = false; interrupted = false; musicEnabled = true }
        else { musicEnabled.toggle() }
    }

    var isMusicPlaying: Bool { musicPlayer?.isPlaying == true }

    var musicIsPaused: Bool { !musicEnabled || routePaused || interrupted }

    private func activateAmbientAudio() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default)
        try session.setActive(true)
    }

    var requestedMusic: ReadLabSound? {
        guard musicEnabled, isActive, !interrupted, !routePaused, !previews, scene != .practice else { return nil }
        return scene == .home ? .home : .onboarding
    }

    /// Fade between music tracks and pause playback while an exercise uses audio.
    private func refreshMusic() {
        transition?.cancel()
        transition = nil
        guard let desired = requestedMusic else {
            musicPlayer?.pause()
            return
        }
        if desired == playingMusic, let player = musicPlayer {
            do {
                try activateAmbientAudio()
                if !player.isPlaying { player.volume = 0; player.play() }
                player.setVolume(desired.volume, fadeDuration: 0.6)
            } catch { }
            return
        }
        let outgoing = musicPlayer
        let fadeOut = outgoing?.isPlaying == true
        if fadeOut { outgoing?.setVolume(0, fadeDuration: 1.2) }
        transition = Task { [weak self] in
            if fadeOut { try? await Task.sleep(for: .seconds(1.2)) }
            guard !Task.isCancelled, let self else { return }
            outgoing?.stop()
            do {
                guard let url = desired.url else { return }
                try self.activateAmbientAudio()
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.volume = 0
                self.musicPlayer = player
                self.playingMusic = desired
                player.play()
                player.setVolume(desired.volume, fadeDuration: 0.8)
            } catch { /* Music is optional; navigation and reading continue normally. */ }
        }
    }
}

private struct ReadLabAudioKey: EnvironmentKey {
    static let defaultValue: ReadLabAudioController? = nil
}

extension EnvironmentValues {
    var readLabAudio: ReadLabAudioController? {
        get { self[ReadLabAudioKey.self] }
        set { self[ReadLabAudioKey.self] = newValue }
    }
}
