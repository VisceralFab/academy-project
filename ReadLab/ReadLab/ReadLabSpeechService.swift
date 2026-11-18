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
    private(set) var inputLevel: Float = 0
    var message: String?
    private(set) var permissionDenied = false

    @ObservationIgnored private var engine: AVAudioEngine?
    // The audio tap and the main actor share the current recognition request.
    @ObservationIgnored private let audioInput = OSAllocatedUnfairLock<SFSpeechAudioBufferRecognitionRequest?>(uncheckedState: nil)
    @ObservationIgnored private var tapInstalled = false
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var segmentTranscript = ""
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var ownsAudioSession = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var resultHandler: ((String, Bool) -> Void)?

    /// Single words can supply a hint. Story reading uses open transcription across segments.
    func start(target: String? = nil, onNewSegment: (() -> Void)? = nil, onResult: @escaping (String, Bool) -> Void) async {
        cancel()
        let token = generation
        transcript = ""
        message = nil
        permissionDenied = false
        isPreparing = true
        defer { if generation == token { isPreparing = false } }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.supportsOnDeviceRecognition else {
            message = "On-device English voice recognition is unavailable here. You can listen and practise with a grown-up."
            return
        }
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == token else { return }
        guard speechPermission == .authorized else {
            permissionDenied = speechPermission == .denied
            message = "Voice recognition is not enabled. You can change access in Settings or practise with a grown-up."
            return
        }
        let microphonePermission = await AVAudioApplication.requestRecordPermission()
        guard generation == token else { return }
        guard microphonePermission else {
            permissionDenied = true
            message = "Microphone access is off. You can change access in Settings or practise with a grown-up."
            return
        }
        guard recognizer.isAvailable else {
            message = "Voice recognition is taking a break. Please try again in a moment."
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
                message = "Connect a microphone and try again."
                return
            }
            let audioInput = self.audioInput
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                audioInput.withLockUnchecked { $0?.append(buffer) }
                // Convert the microphone signal to a 0–1 level for the visual meter.
                var amplitude: Float = 0
                if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                    let count = Int(buffer.frameLength)
                    var sum: Float = 0
                    for i in 0..<count { sum += samples[i] * samples[i] }
                    amplitude = min(1, sqrt(sum / Float(count)) * 12)
                }
                let level = amplitude
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token, self.isListening else { return }
                    self.inputLevel = level
                }
            }
            tapInstalled = true
            resultHandler = onResult
            beginRecognition(with: recognizer, target: target, onNewSegment: onNewSegment)
            engine.prepare()
            try engine.start()
            isListening = true
        } catch {
            cancel()
            message = "The microphone couldn’t start. Please try again."
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
        recognitionTask?.cancel()
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.requestID == id else { return }
                if let text, !text.isEmpty {
                    self.segmentTranscript = text
                    self.transcript = text
                    self.resultHandler?(text, final)
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
                    // Audio failures leave the current story position available for a retry.
                    self.cancel()
                    self.message = "I couldn’t hear clearly. Tap the microphone to continue."
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
        inputLevel = 0
        engine?.stop()
        audioInput.withLockUnchecked { $0?.endAudio(); $0 = nil }
        timeoutTask?.cancel()
        let id = requestID
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.requestID == id else { return }
            let lastText = self.segmentTranscript
            let handler = self.resultHandler
            self.cancel()
            if lastText.isEmpty { self.message = "I didn’t catch any words. Tap the microphone to try again." }
            else { handler?(lastText, true) }
        }
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
        inputLevel = 0
        if ownsAudioSession {
            ownsAudioSession = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

/// Plays a spoken example before microphone capture begins.
@MainActor
final class ReadLabSpeaker {
    private let synthesizer = AVSpeechSynthesizer()
    private var ownsAudioSession = false
    func speak(_ text: String) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            ownsAudioSession = true
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.38
            synthesizer.speak(utterance)
        } catch { /* Text stays visible when audio output is unavailable. */ }
    }
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        if ownsAudioSession {
            ownsAudioSession = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
