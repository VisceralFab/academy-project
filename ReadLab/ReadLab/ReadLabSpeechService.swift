import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
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
    @ObservationIgnored private var finalizationTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var resultHandler: ((String, Bool) -> Void)?
    @ObservationIgnored private var tapInstalled = false
    
    func start(target: String, onResult: @escaping (String, Bool) -> Void) async {
        cancel()
        let token = generation
        
        transcript = ""
        message = nil
        permissionDenied = false
        isPreparing = true
        defer {
            if generation == token { isPreparing = false }
        }
        
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.supportsOnDeviceRecognition else {
            message = "On-device English voice recognition is unavailable here. You can practise with a grown-up."
            return
        }
        
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard generation == token else { return }
        guard speechPermission == .authorized else {
            permissionDenied = (speechPermission == .denied || speechPermission == .restricted)
            message = "Speech recognition is not enabled. Check access in Settings."
            return
        }
        
        let microphonePermission = await AVAudioApplication.requestRecordPermission()
        guard generation == token else { return }
        guard microphonePermission else {
            permissionDenied = true
            message = "Microphone access is off. Check access in Settings."
            return
        }
        
        guard recognizer.isAvailable else {
            message = "Voice recognition is temporarily unavailable. Please try again."
            return
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true)
            
            let engine = AVAudioEngine()
            self.engine = engine
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            if !target.isEmpty { request.contextualStrings = [target] }
            self.request = request
            resultHandler = onResult
            
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw NSError(domain: "ReadLab.Audio", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No usable microphone input format."])
            }
            
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                
                var level: Float = 0
                if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                    let count = Int(buffer.frameLength)
                    var sum: Float = 0
                    for index in 0..<count { sum += samples[index] * samples[index] }
                    level = min(1, sqrt(sum / Float(count)) * 12)
                }
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token, self.isListening else { return }
                    self.inputLevel = level
                }
            }
            tapInstalled = true
            
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let recognizedText = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let recognitionError = error.map { $0 as NSError }
                
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    
                    if let recognizedText {
                        self.transcript = recognizedText
                        print("🎙️ Recognized: \(recognizedText)")
                        self.resultHandler?(recognizedText, isFinal)
                        guard self.generation == token else { return }
                    }
                    
                    if isFinal {
                        print("✅ Speech recognition finished")
                        self.cancel()
                    } else if let recognitionError {
                        print("❌ Recognition error: \(recognitionError.domain) [\(recognitionError.code)] \(recognitionError.localizedDescription)")
                        let lastText = self.transcript
                        let handler = self.resultHandler
                        self.cancel()
                        if !lastText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            handler?(lastText, true)
                        } else {
                            self.message = "Voice recognition failed (error \(recognitionError.code)). Please try again."
                        }
                        if recognitionError.domain == "kLSRErrorDomain",
                           recognitionError.code == 201 {
                            
                            self.message = """
                            Voice recognition needs Dictation enabled.
                            Ask a grown-up to turn it on in iPad Settings.
                            """
                            
                        } else {
                            self.message = """
                            I couldn't recognize your voice.
                            Please try again.
                            """
                        }
                    }
                }
            }
            
            engine.prepare()
            try engine.start()
            isListening = true
            print("✅ Audio engine started")
            print("Input sample rate: \(format.sampleRate)")
            print("Input channels: \(format.channelCount)")
            print("Recognizer available: \(recognizer.isAvailable)")
            print("On-device recognition supported: \(recognizer.supportsOnDeviceRecognition)")
            
            timeoutTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(14)) }
                catch { return }
                guard let self, self.generation == token else { return }
                self.finishListening()
            }
        } catch {
            let nsError = error as NSError
            print("❌ Microphone startup failed: \(nsError.domain) [\(nsError.code)] \(nsError.localizedDescription)")
            cancel()
            message = "The microphone couldn't start. Please try again."
        }
    }
    
    func finishListening() {
        guard isListening else { return }
        isFinishing = true
        isListening = false
        inputLevel = 0
        timeoutTask?.cancel()
        timeoutTask = nil
        
        engine?.stop()
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        print("🎙️ Recording stopped. Processing speech...")
        
        let token = generation
        finalizationTask?.cancel()
        finalizationTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) }
            catch { return }
            guard let self, self.generation == token else { return }
            
            let lastText = self.transcript
            let handler = self.resultHandler
            self.cancel()
            if lastText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.message = "I didn't catch any words. Tap the microphone to try again."
            } else {
                handler?(lastText, true)
            }
        }
    }
    
    func cancel() {
        generation = UUID()
        timeoutTask?.cancel()
        timeoutTask = nil
        finalizationTask?.cancel()
        finalizationTask = nil
        
        engine?.stop()
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor
@Observable
final class ReadLabSpeaker {
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    
    func speak(_ text: String) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.38
            synthesizer.speak(utterance)
        } catch {
            print("❌ Speaker error: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        // Do not deactivate the shared AVAudioSession here: the microphone may be using it.
        synthesizer.stopSpeaking(at: .immediate)
    }
}
