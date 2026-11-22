import AVFoundation
import os

/// Synthesizes a short reply in memory, then raises both pitch and formants by speeding up playback.
@MainActor
final class ReadLabParrotPlayer {
    enum Outcome { case played, unavailable, cancelled }

    private let synthesizer = AVSpeechSynthesizer()
    private var activeID: UUID?
    private var completion: CheckedContinuation<Outcome, Never>?
    private var deadline: Task<Void, Never>?
    private var engine: AVAudioEngine?
    private var node: AVAudioPlayerNode?
    private var ownsAudioSession = false

    func play(_ word: String) async -> Outcome {
        stop()
        guard !Task.isCancelled else { return .cancelled }
        let id = UUID()
        activeID = id
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.36
        utterance.pitchMultiplier = 1.22

        // The callback stays off the main actor and hands the buffers over as a single ordered batch.
        let rendered = OSAllocatedUnfairLock<[AVAudioPCMBuffer]>(uncheckedState: [])
        return await withCheckedContinuation { continuation in
            completion = continuation
            deadline = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.finish(id, outcome: .unavailable)
            }
            synthesizer.write(utterance, toBufferCallback: { @Sendable [weak self] buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else {
                    Task { @MainActor [weak self] in self?.finish(id, outcome: .unavailable) }
                    return
                }
                if pcm.frameLength == 0 {
                    Task { @MainActor [weak self] in
                        self?.playRendered(rendered.withLockUnchecked { $0 }, id: id)
                    }
                } else if let copy = Self.copy(pcm) {
                    rendered.withLockUnchecked { $0.append(copy) }
                } else {
                    Task { @MainActor [weak self] in self?.finish(id, outcome: .unavailable) }
                }
            })
        }
    }

    func stop() {
        if let activeID { finish(activeID, outcome: .cancelled) }
    }

    private nonisolated static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let target = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else { return nil }
        target.frameLength = source.frameLength
        let inputs = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let outputs = UnsafeMutableAudioBufferListPointer(target.mutableAudioBufferList)
        for (input, output) in zip(inputs, outputs) {
            guard let src = input.mData, let dst = output.mData else { return nil }
            memcpy(dst, src, Int(min(input.mDataByteSize, output.mDataByteSize)))
        }
        return target
    }

    private func playRendered(_ buffers: [AVAudioPCMBuffer], id: UUID) {
        guard activeID == id, engine == nil else { return }
        deadline?.cancel()
        deadline = nil
        guard let inputFormat = buffers.first?.format,
              buffers.allSatisfy({ $0.format == inputFormat }),
              let format = AVAudioFormat(standardFormatWithSampleRate: inputFormat.sampleRate, channels: inputFormat.channelCount)
        else {
            finish(id, outcome: .unavailable)
            return
        }
        do {
            let buffers = try playbackBuffers(buffers, from: inputFormat, to: format)
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .spokenAudio)
            try audio.setActive(true)
            ownsAudioSession = true

            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let voice = AVAudioUnitVarispeed()
            voice.rate = 1.40
            player.volume = 0.66
            self.engine = engine
            self.node = player
            engine.attach(player)
            engine.attach(voice)
            try engine.connectNode(player, to: voice, format: format)
            try engine.connectNode(voice, to: engine.mainMixerNode, format: format)
            try engine.start()
            for buffer in buffers.dropLast() { player.scheduleBuffer(buffer) }
            if let last = buffers.last {
                player.scheduleBuffer(last, completionCallbackType: .dataPlayedBack) { @Sendable [weak self] _ in
                    Task { @MainActor [weak self] in self?.finish(id, outcome: .played) }
                }
            }
            try player.playAudio()
            let seconds = buffers.reduce(0.0) { $0 + Double($1.frameLength) } / format.sampleRate / Double(voice.rate)
            deadline = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds + 2))
                guard !Task.isCancelled else { return }
                self?.finish(id, outcome: .cancelled)
            }
        } catch {
            finish(id, outcome: .unavailable)
        }
    }

    private func playbackBuffers(_ source: [AVAudioPCMBuffer], from input: AVAudioFormat,
                                 to output: AVAudioFormat) throws -> [AVAudioPCMBuffer] {
        if input == output { return source }
        guard let converter = AVAudioConverter(from: input, to: output) else { throw RenderError.badFormat }
        return try source.map { buffer in
            guard let result = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: buffer.frameLength) else {
                throw RenderError.badFormat
            }
            try converter.convert(to: result, from: buffer)
            return result
        }
    }

    private enum RenderError: Error { case badFormat }

    private func finish(_ id: UUID, outcome: Outcome) {
        guard activeID == id else { return }
        activeID = nil
        deadline?.cancel()
        deadline = nil
        synthesizer.stopSpeaking(at: .immediate)
        node?.stop()
        engine?.stop()
        node = nil
        engine = nil
        if ownsAudioSession {
            ownsAudioSession = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        let finished = completion
        completion = nil
        finished?.resume(returning: outcome)
    }
}
