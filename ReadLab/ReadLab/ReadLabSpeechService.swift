import AVFoundation
import Foundation
import Observation
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
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var ownsAudioSession = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var resultHandler: ((String, Bool) -> Void)?

    func start(target: String, duration: TimeInterval = 14, onResult: @escaping (String, Bool) -> Void) async {
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
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            request.contextualStrings = [target]
            self.request = request
            self.resultHandler = onResult
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else {
                throw NSError(domain: "ReadLab.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "No microphone is available. Try again when a microphone is connected."])
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                var amplitude: Float = 0
                if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                    let count = Int(buffer.frameLength)
                    var sum: Float = 0
                    for i in 0..<count { sum += samples[i] * samples[i] }
                    amplitude = min(1, sqrt(sum / Float(count)) * 12)
                }
                let level = amplitude
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.inputLevel = level
                }
            }
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                let errorText = error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if let text {
                        self.transcript = text
                        self.resultHandler?(text, final)
                        guard self.generation == token else { return }
                    }
                    if final { self.cancel() }
                    else if errorText != nil {
                        // Recognition errors are not reading mistakes.
                        self.cancel()
                        self.message = "I couldn’t hear clearly. Find a quiet spot and try again."
                    }
                }
            }
            engine.prepare()
            try engine.start()
            isListening = true
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled, let self, self.generation == token else { return }
                self.finishListening()
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, self.generation == token else { return }
                let lastText = self.transcript
                let handler = self.resultHandler
                self.cancel()
                if lastText.isEmpty { self.message = "I didn’t catch any words. Tap the microphone to try again." }
                else { handler?(lastText, true) }
            }
        } catch {
            cancel()
            message = "The microphone couldn’t start. Please try again."
        }
    }

    func finishListening() {
        guard isListening else { return }
        isFinishing = true
        engine?.stop()
        request?.endAudio()
        isListening = false
        inputLevel = 0
    }

    func cancel() {
        generation = UUID()
        timeoutTask?.cancel()
        timeoutTask = nil
        engine?.stop()
        if let engine { engine.inputNode.removeTap(onBus: 0) }
        engine = nil
        request?.endAudio()
        request = nil
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

@MainActor @Observable
final class ReadLabSpeaker {
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var ownsAudioSession = false
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
