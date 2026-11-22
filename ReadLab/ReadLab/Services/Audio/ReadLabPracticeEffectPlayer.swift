import AVFoundation

/// Plays short exercise effects while the speech recognizer is stopped.
@MainActor
final class ReadLabPracticeEffectPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var completion: CheckedContinuation<Void, Never>?

    func play(_ sound: ReadLabSound) async {
        guard !Task.isCancelled, let url = sound.url else { return }
        stop()

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            self.player = player
            player.delegate = self
            player.volume = sound.volume

            await withCheckedContinuation { continuation in
                completion = continuation
                if !player.play() { stop() }
            }
        } catch {
            // Exercises can continue when an effect cannot be played.
        }
    }

    func stop() {
        guard let player else { return }
        self.player = nil
        player.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let continuation = completion
        completion = nil
        continuation?.resume()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        finish(id: ObjectIdentifier(player))
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error _: Error?) {
        finish(id: ObjectIdentifier(player))
    }

    private nonisolated func finish(id: ObjectIdentifier) {
        Task { @MainActor in
            guard let player, ObjectIdentifier(player) == id else { return }
            stop()
        }
    }
}
