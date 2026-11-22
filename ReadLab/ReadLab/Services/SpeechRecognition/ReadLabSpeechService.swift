import AVFoundation
import Foundation
import Observation
import os
import Speech

@MainActor @Observable
final class ReadLabSpeechService {
    private(set) var isListening = false
    private(set) var isPreparing = false
    private(set) var isFinishing = false
    private(set) var transcript = ""
    var message: String?
    private(set) var permissionDenied = false
    private(set) var canRetry = false

    @ObservationIgnored private var engine: AVAudioEngine?
    // The audio tap and the main actor share the current recognition request.
    @ObservationIgnored private let audioInput = OSAllocatedUnfairLock<SFSpeechAudioBufferRecognitionRequest?>(uncheckedState: nil)
    @ObservationIgnored private var tapInstalled = false
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var segmentTranscript = ""
    @ObservationIgnored private var segmentAlternatives = SpeechWordAlternatives()
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var ownsAudioSession = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var resultHandler: ((String, Bool, SpeechWordAlternatives) -> Void)?

    @ObservationIgnored private var listeningEnded: CheckedContinuation<Void, Never>?

    /// Wait for capture to end before starting another attempt or playing a spoken prompt.
    func listen(target: String? = nil, onNewSegment: (() -> Void)? = nil,
                onResult: @escaping (String, Bool, SpeechWordAlternatives) -> Void) async {
        guard !Task.isCancelled else { return }
        cancel()
        let token = generation
        await start(token: token, target: target, onNewSegment: onNewSegment, onResult: onResult)
        guard generation == token, !Task.isCancelled, isListening || isFinishing else { return }
        await withCheckedContinuation { listeningEnded = $0 }
    }

    /// Single words can supply a hint. Story reading uses open transcription across segments.
    private func start(token: UUID, target: String?, onNewSegment: (() -> Void)?,
                       onResult: @escaping (String, Bool, SpeechWordAlternatives) -> Void) async {
        transcript = ""
        message = nil
        permissionDenied = false
        canRetry = false
        isPreparing = true
        defer { if generation == token { isPreparing = false } }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.supportsOnDeviceRecognition else {
            message = "On-device English voice recognition is unavailable here. You can listen and practise with a grown-up."
            return
        }
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == token, !Task.isCancelled else { return }
        guard speechPermission == .authorized else {
            permissionDenied = speechPermission == .denied
            message = "Voice recognition is not enabled. You can change access in Settings or practise with a grown-up."
            return
        }
        let microphonePermission = await AVAudioApplication.requestRecordPermission()
        guard generation == token, !Task.isCancelled else { return }
        guard microphonePermission else {
            permissionDenied = true
            message = "Microphone access is off. You can change access in Settings or practise with a grown-up."
            return
        }
        guard recognizer.isAvailable else {
            canRetry = true
            message = "Voice recognition is taking a break."
            return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            ownsAudioSession = true
            let engine = AVAudioEngine()
            self.engine = engine
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else {
                cancel()
                canRetry = true
                message = "Connect a microphone to read aloud."
                return
            }
            let audioInput = self.audioInput
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                audioInput.withLockUnchecked { $0?.append(buffer) }
            }
            tapInstalled = true
            resultHandler = onResult
            beginRecognition(with: recognizer, target: target, onNewSegment: onNewSegment)
            engine.prepare()
            try engine.start()
            isListening = true
        } catch {
            cancel()
            canRetry = true
            message = "The microphone couldn’t start."
        }
    }

    /// Swap recognition requests while keeping the same audio engine and microphone tap.
    private func beginRecognition(with recognizer: SFSpeechRecognizer, target: String?, onNewSegment: (() -> Void)?) {
        requestID = UUID()
        let id = requestID
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        if let target { request.contextualStrings = [target] }
        segmentTranscript = ""
        segmentAlternatives = SpeechWordAlternatives()
        recognitionTask?.cancel()
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let best = result?.bestTranscription
            let text = best?.formattedString
            let segments = onNewSegment == nil ? [] : (best?.segments ?? []).map {
                SpeechWordAlternatives.Segment(range: $0.substringRange, alternatives: $0.alternativeSubstrings)
            }
            let candidates = onNewSegment == nil ? [] : (result?.transcriptions ?? []).prefix(4).map(\.formattedString)
            let final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.requestID == id else { return }
                if let text, !text.isEmpty {
                    self.segmentTranscript = text
                    self.transcript = text
                    let alternatives = SpeechWordAlternatives(text: text, segments: segments, transcripts: candidates)
                    self.segmentAlternatives = alternatives
                    self.resultHandler?(text, final, alternatives)
                    guard self.requestID == id else { return }
                }
                if final {
                    self.recognitionTask = nil
                    if let onNewSegment, self.isListening, !self.segmentTranscript.isEmpty {
                        onNewSegment()
                        self.beginRecognition(with: recognizer, target: target, onNewSegment: onNewSegment)
                    } else {
                        self.cancel()
                    }
                } else if failed {
                    // The exercise renews the request from the saved reading position.
                    self.cancel()
                }
            }
        }
        audioInput.withLockUnchecked { current in
            current?.endAudio()
            current = request
        }
        recognitionTask = task
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(onNewSegment == nil ? 14 : 55))
            guard !Task.isCancelled, let self, self.requestID == id else { return }
            if let onNewSegment, self.isListening, !self.segmentTranscript.isEmpty {
                // Keep a slow reading session going past the lifetime of a single request.
                onNewSegment()
                self.beginRecognition(with: recognizer, target: target, onNewSegment: onNewSegment)
            } else {
                self.finishListening()
            }
        }
    }

    /// End input and give the recognizer a short window to deliver its final words.
    func finishListening() {
        guard isListening else { return }
        isFinishing = true
        isListening = false
        engine?.stop()
        audioInput.withLockUnchecked { $0?.endAudio(); $0 = nil }
        timeoutTask?.cancel()
        let id = requestID
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.requestID == id else { return }
            let lastText = self.segmentTranscript
            let handler = self.resultHandler
            let alternatives = self.segmentAlternatives
            self.cancel()
            if !lastText.isEmpty { handler?(lastText, true, alternatives) }
        }
    }

    func reportInterruption() {
        canRetry = true
        message = "Listening was interrupted."
    }

    func cancel() {
        generation = UUID()
        requestID = UUID()
        timeoutTask?.cancel()
        timeoutTask = nil
        engine?.stop()
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine = nil
        audioInput.withLockUnchecked { $0?.endAudio(); $0 = nil }
        recognitionTask?.cancel()
        recognitionTask = nil
        resultHandler = nil
        isListening = false
        isPreparing = false
        isFinishing = false
        if ownsAudioSession {
            ownsAudioSession = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        let continuation = listeningEnded
        listeningEnded = nil
        continuation?.resume()
    }
}

/// Releases the playback session before handing audio back to recognition.
@MainActor @Observable
final class ReadLabSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var utteranceID: ObjectIdentifier?
    @ObservationIgnored private var playbackEnded: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, pitch: Float = 1) async -> Bool {
        stop()
        guard !Task.isCancelled else { return false }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .spokenAudio)
            try audio.setActive(true)
        } catch {
            return false
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.38
        utterance.pitchMultiplier = pitch
        utteranceID = ObjectIdentifier(utterance)
        isSpeaking = true
        return await withCheckedContinuation { continuation in
            playbackEnded = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        guard let id = utteranceID else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finish(id, completed: false)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finish(id, completed: true) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finish(id, completed: false) }
    }

    private func finish(_ id: ObjectIdentifier, completed: Bool) {
        guard utteranceID == id else { return }
        utteranceID = nil
        isSpeaking = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let continuation = playbackEnded
        playbackEnded = nil
        continuation?.resume(returning: completed)
    }
}
