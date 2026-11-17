import SwiftUI
import AVFoundation

struct ReadLabExerciseView: View {
    let store: ReadLabStore
    @State private var session: PracticeSession
    @State private var speech = ReadLabSpeechService()
    @State private var speaker = ReadLabSpeaker()
    @State private var zoom = 0.35
    @State private var syllablePosition = 0.0
    @State private var feedback = ""
    @State private var readingOffset = 0
    @State private var wrongOptions: Set<Int> = []
    @State private var adultCheckPresented = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    init(store: ReadLabStore, initialSession: PracticeSession) {
        self.store = store
        var restored = initialSession
        if restored.path == .stories {
            restored.prepareStoryReading(in: ReadLabLibrary.story(theme: restored.themeID, level: restored.contentLevel))
        }
        _session = State(initialValue: restored)
    }
    private var theme: ReadingTheme { ReadingTheme.find(session.themeID) }
    private var prompts: [ReadingPrompt] { ReadLabLibrary.prompts(theme: session.themeID, level: session.contentLevel) }
    private var prompt: ReadingPrompt { prompts[min(session.itemIndex, prompts.count - 1)] }
    private var story: ReadingStory { ReadLabLibrary.story(theme: session.themeID, level: session.contentLevel) }
    private var question: StoryQuestion { story.questions[min(session.questionIndex, story.questions.count - 1)] }

    private var reading: StoryReadingProgress { session.storyReading ?? StoryReadingProgress() }
    private var paragraphs: [String] { story.sections[min(session.sectionIndex, story.sections.count - 1)] }
    private var activeParagraph: String { paragraphs[min(reading.paragraphIndex, paragraphs.count - 1)] }
    private var storyAdvanceID: String {
        "\(session.sectionIndex)-\(reading.paragraphIndex)-\(reading.paragraphComplete)-\(session.showingQuestions)-\(scenePhase == .active)"
    }
    private var hearingPreviewID: String { "\(session.itemIndex)-\(scenePhase == .active)" }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 850 || typeSize.isAccessibilitySize
            ZStack {
                ReadLabPastelBackground(path: session.path)
                VStack(spacing: 16) {
                    header(compact: compact)
                    if session.completed { completion }
                    else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 26) {
                                    if session.path == .stories { reader(compact: compact) }
                                    else { voicePractice(compact: compact) }
                                }
                                .padding(compact ? 22 : 40)
                                .frame(maxWidth: .infinity, minHeight: max(300, geo.size.height - 300))
                                .background(.white, in: RoundedRectangle(cornerRadius: 30))
                                .id("practiceTop")
                            }
                            .scrollIndicators(.hidden)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                            .onChange(of: session.sectionIndex) { _, _ in proxy.scrollTo("practiceTop", anchor: .top) }
                            .onChange(of: reading.paragraphIndex) { _, index in proxy.scrollTo("storyParagraph-\(index)", anchor: .center) }
                            .onChange(of: session.questionIndex) { _, _ in proxy.scrollTo("practiceTop", anchor: .top) }
                        }
                        .shadow(color: ReadLabStyle.ink.opacity(0.08), radius: 12, y: 6)
                        controls(compact: compact)
                    }
                }
                .frame(maxWidth: 1300)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, compact ? 20 : 64)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
        }
        .foregroundStyle(ReadLabStyle.ink)
        .confirmationDialog("Read together", isPresented: $adultCheckPresented, titleVisibility: .visible) {
            Button("A grown-up checked this reading") { markAssistedReading() }
        } message: {
            Text("Continue after a grown-up listens to this reading. This practice won’t change the automatic difficulty.")
        }
        .task(id: session.answeredCurrentItem) {
            guard session.answeredCurrentItem, session.path != .stories, !session.completed else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, scenePhase == .active else { return }
            nextPrompt()
        }
        .task(id: hearingPreviewID) {
            guard session.path == .hearing, !session.answeredCurrentItem, !session.completed, scenePhase == .active else { return }
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled, !speech.isPreparing, !speech.isListening, !speech.isFinishing else { return }
            playPreview(prompt.text)
        }
        .task(id: storyAdvanceID) {
            guard session.path == .stories, !session.completed, !session.showingQuestions,
                  reading.paragraphComplete, scenePhase == .active else { return }
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            nextStoryStep()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.didBecomeInactiveNotification)) { notification in
            if let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
               context.source == .system { stopAudio() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            if notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { stopAudio() }
        }
        .onChange(of: session) { _, value in store.update(value) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopAudio(); store.update(session) }
        }
        .onDisappear { stopAudio(); store.update(session) }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 18) {
            Button("Close activity", systemImage: "xmark") { stopAudio(); store.update(session); dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityIdentifier("closeActivityButton")
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.title).readLabFont(compact ? 24 : 30, weight: .bold)
                Text(session.path.title).readLabFont(16, rounded: false)
            }
            Spacer(minLength: 0)
            if !session.completed {
                Text(progressLabel).readLabFont(17, weight: .medium)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("exerciseProgress")
            }
        }
    }
    private var progressLabel: String {
        if session.path != .stories { return "\(min(session.itemIndex + 1, 6)) of 6" }
        return session.showingQuestions ? "Question \(session.questionIndex + 1) of \(story.questions.count)" : "Section \(session.sectionIndex + 1) of \(story.sections.count)"
    }

    private func voicePractice(compact: Bool) -> some View {
        VStack(spacing: compact ? 24 : 34) {
            Text(session.path == .hearing ? "Listen. Say it. Watch it grow." : "Take it one syllable at a time.")
                .readLabFont(21, weight: .light, rounded: false)
                .multilineTextAlignment(.center)
            if session.path == .hearing {
                Button { playPreview(prompt.text) } label: {
                    Text(prompt.text)
                        .readLabFont(compact ? 42 : 58, weight: .semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(session.answeredCurrentItem ? Color(red: 0.22, green: 0.43, blue: 0.28) : ReadLabStyle.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Listen to \(prompt.text)")
                .accessibilityHint("Hear the word before reading it aloud")
                .accessibilityIdentifier("readingPrompt")
                WateringTreeView(listening: speech.isListening, success: session.answeredCurrentItem)
                    .frame(height: compact ? 210 : 250)
            } else {
                syllableReader(compact: compact)

            }
            feedbackView
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: session.answeredCurrentItem)
    }

    private var syllableParts: [String] {
        prompt.syllables.flatMap { $0.components(separatedBy: .whitespaces) }.filter { !$0.isEmpty }
    }
    /// The lens and its track share the measured width of the syllables.
    private func syllableReader(compact: Bool) -> some View {
        ReadLabSyllableExplorer(parts: syllableParts,
                               pointSize: (compact ? 35 : 48) + zoom * 25,
                               completed: session.answeredCurrentItem,
                               position: $syllablePosition)
    }

    @ViewBuilder private var feedbackView: some View {
        if session.answeredCurrentItem {
            Label("Lovely reading!", systemImage: "checkmark.seal.fill")
                .readLabFont(24, weight: .semibold)
                .foregroundStyle(Color(red: 0.22, green: 0.43, blue: 0.28))
                .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.95)))
                .accessibilityIdentifier("readingSuccess")
        } else if let message = speech.message {
            VStack(spacing: 12) {
                Text(message).readLabFont(18, rounded: false).multilineTextAlignment(.center)
                if speech.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url).buttonStyle(.bordered)
                }
            }
        } else if !feedback.isEmpty {
            Text(feedback).readLabFont(20, weight: .medium).multilineTextAlignment(.center)
        } else if speech.isListening {
            VStack(spacing: 10) {
                Label("I’m listening…", systemImage: "waveform").readLabFont(21, weight: .medium)
                ProgressView(value: Double(speech.inputLevel)).frame(width: 180).accessibilityLabel("Microphone input level")
                if !speech.transcript.isEmpty { Text(speech.transcript).readLabFont(18, rounded: false) }
            }
        } else {
            Text(session.path == .words
                 ? "Tap the microphone and say the word clearly."
                 : "Tap the word to listen, then the microphone to read aloud.")
                .readLabFont(18, rounded: false).multilineTextAlignment(.center)
        }
    }

    private func reader(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            if session.showingQuestions {
                Text("A little story check").readLabFont(21, weight: .light, rounded: false)
                Text(question.text).readLabFont(compact ? 32 : 42, weight: .medium)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button { answerQuestion(index) } label: {
                        HStack(spacing: 16) {
                            Text(option).readLabFont(24, weight: .medium)
                            Spacer()
                            Image(systemName: session.answeredCurrentItem && index == question.answer ? "checkmark.circle.fill" : (wrongOptions.contains(index) ? "arrow.counterclockwise.circle" : "circle"))
                                .font(.title2)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .background(session.answeredCurrentItem && index == question.answer ? ReadLabStyle.sky : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(ReadLabTapStyle())
                    .disabled(session.answeredCurrentItem || wrongOptions.contains(index))
                    .accessibilityIdentifier("answerOption\(index)")
                }
                if session.answeredCurrentItem {
                    Label("You found it!", systemImage: "checkmark.seal.fill").readLabFont(23, weight: .semibold)
                } else if !feedback.isEmpty {
                    Text(feedback).readLabFont(20)
                    Text(question.hint).readLabFont(18, rounded: false)
                }
            } else {
                Text(story.title).readLabFont(compact ? 32 : 44, weight: .semibold)
                    .accessibilityAddTraits(.isHeader)
                if !feedback.isEmpty { Text(feedback).readLabFont(18, weight: .medium).padding().background(ReadLabStyle.sand.opacity(0.5), in: RoundedRectangle(cornerRadius: 16)) }
                Text("Paragraph \(reading.paragraphIndex + 1) of \(paragraphs.count) · \(reading.wordCount) of \(ReadingAlignment.wordCount(in: activeParagraph)) words read")
                    .readLabFont(17, weight: .medium, rounded: false)
                    .accessibilityIdentifier("storyReadingProgress")
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    let count = index < reading.paragraphIndex ? ReadingAlignment.wordCount(in: paragraph) : (index == reading.paragraphIndex ? reading.wordCount : 0)
                    Button { playPreview(paragraph) } label: {
                        Text(ReadingAlignment.highlighted(paragraph, through: count))
                            .readLabFont(24 + zoom * 22)
                            .lineSpacing(12)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(index == reading.paragraphIndex ? ReadLabStyle.sky : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Listen to this paragraph")
                    .accessibilityValue("\(count) of \(ReadingAlignment.wordCount(in: paragraph)) words read")
                    .accessibilityIdentifier("storyParagraph\(index)")
                    .id("storyParagraph-\(index)")
                }
                storyFeedback

            }
        }
        .frame(maxWidth: 960, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: 12) {
            if session.path == .words || (session.path == .stories && !session.showingQuestions) {
                HStack(spacing: 16) {
                    Image(systemName: "textformat.size.smaller")
                    Slider(value: $zoom, in: 0...1).accessibilityLabel("Reading text size")
                    Image(systemName: "textformat.size.larger")
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.white, in: Capsule())
                .frame(maxWidth: 650)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { controlButtons }
                VStack(spacing: 14) { controlButtons }
            }
        }
    }
    @ViewBuilder private var controlButtons: some View {
        if session.path == .stories {
            if !session.showingQuestions {
                HStack(spacing: 24) {
                    Button("Previous", systemImage: "chevron.left") { previousParagraph() }
                        .labelStyle(.iconOnly)
                        .disabled(session.sectionIndex == 0 && reading.paragraphIndex == 0)
                        .buttonStyle(.bordered).buttonBorderShape(.circle).controlSize(.large)
                    Menu {
                        Button("Practise with a Grown-up", systemImage: "person.2") { stopAudio(); adultCheckPresented = true }
                    } label: { Label("More", systemImage: "ellipsis") }
                    .labelStyle(.iconOnly).buttonStyle(.bordered).buttonBorderShape(.circle).controlSize(.large)
                    microphone(completed: reading.paragraphComplete, action: toggleStoryMicrophone)
                }
            } else {
                Button("Read Again", systemImage: "book") {
                    stopAudio()
                    feedback = ""; wrongOptions = []; session.showingQuestions = false; session.sectionIndex = 0
                    session.questionIndex = 0; session.answeredCurrentItem = false; session.storyReading = StoryReadingProgress()
                }.buttonStyle(.bordered).controlSize(.large)
                ReadLabActionButton(title: session.questionIndex == story.questions.count - 1 ? "Finish Story" : "Next Question", action: nextQuestion, enabled: session.answeredCurrentItem)
            }
        } else {
            HStack(spacing: 30) {
                if session.path == .words {
                    // First words only moves on after the word is recognised: no skip or bypass options.
                    Color.clear.frame(width: 48, height: 48)
                } else {
                    Menu {
                        Button("Practise with a Grown-up", systemImage: "person.2") { stopAudio(); adultCheckPresented = true }
                        Button("Try Another Word", systemImage: "arrow.right") { nextPrompt() }
                    } label: { Label("More", systemImage: "ellipsis") }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                }
                Spacer(minLength: 8)
                microphone(completed: session.answeredCurrentItem) {
                    speaker.stop()
                    if speech.isListening { speech.finishListening() }
                    else { Task { await speech.start(target: prompt.text, onResult: handleSpeech) } }
                }
                Spacer(minLength: 8)
                if session.answeredCurrentItem {
                    Button(session.itemIndex == 5 ? "Finish" : "Next Word", systemImage: "arrow.right") { nextPrompt() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(ReadLabStyle.actionFill)
                        .foregroundStyle(.white)
                } else { Color.clear.frame(width: 48, height: 48) }
            }
            .frame(maxWidth: 420)
            .padding(.vertical, 6)
        }
    }

    private func microphone(completed: Bool, action: @escaping () -> Void) -> some View {
        ReadLabMicrophoneButton(listening: speech.isListening, preparing: speech.isPreparing,
                                finishing: speech.isFinishing, inputLevel: speech.inputLevel,
                                completed: completed, action: action)
    }

    @ViewBuilder private var storyFeedback: some View {
        if reading.paragraphComplete {
            Label("Lovely reading!", systemImage: "checkmark.seal.fill")
                .readLabFont(22, weight: .semibold)
                .accessibilityIdentifier("paragraphSuccess")
        } else if let message = speech.message {
            VStack(alignment: .leading, spacing: 8) {
                Text(message).readLabFont(18, rounded: false)
                if speech.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url).buttonStyle(.bordered)
                }
            }
        } else if speech.isListening || speech.isFinishing {
            Label(speech.isFinishing ? "Checking your reading…" : "I’m listening…", systemImage: "waveform")
                .readLabFont(18, weight: .medium)
        } else {
            Text("Tap the microphone and read the outlined paragraph. Start at the first unhighlighted word.")
                .readLabFont(18, rounded: false)
        }
    }

    private func toggleStoryMicrophone() {
        speaker.stop()
        guard !reading.paragraphComplete else { return }
        if speech.isListening { speech.finishListening(); return }
        feedback = ""
        readingOffset = reading.wordCount
        let target = SpeechMatch.normalized(activeParagraph).split(separator: " ").dropFirst(readingOffset).joined(separator: " ")
        Task { await speech.start(target: target, duration: max(30, min(90, Double(ReadingAlignment.wordCount(in: target)) * 1.5)), onResult: handleStorySpeech) }
    }

    private func handleStorySpeech(_ text: String, _ final: Bool) {
        guard !session.completed, !session.showingQuestions, !reading.paragraphComplete, scenePhase == .active else { return }
        guard let alignment = session.updateStoryReading(transcript: text, startingAt: readingOffset, in: story) else { return }
        if alignment.isComplete {
            speech.cancel()
            _ = store.record(success: true, path: .stories, themeID: session.themeID, item: activeParagraph)
            feedback = ""
        } else if final, !SpeechMatch.normalized(text).isEmpty {
            speech.cancel()
            if alignment.containsMismatch {
                _ = store.record(success: false, path: .stories, themeID: session.themeID, item: activeParagraph)
            }
            // Keep this version of the story stable, even if the next activity adapts its level.
            feedback = "Take your time. Tap the microphone and continue at the first unhighlighted word."
        }
    }

    private func playPreview(_ text: String) {
        speech.cancel()
        feedback = ""
        speaker.speak(text)
    }

    private var completion: some View {
        VStack(spacing: 28) {
            Image(session.path.mascot).resizable().scaledToFit().frame(height: 200).accessibilityHidden(true)
            Text("A little practice. A big adventure.").readLabFont(40, weight: .semibold).multilineTextAlignment(.center)
            Text("You explored \(theme.title). Every little effort helps you grow.")
                .readLabFont(23, rounded: false).multilineTextAlignment(.center)
            ReadLabActionButton(title: "Back to Discoveries") { dismiss() }
        }
        .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("activityCompleted")
    }

    private func handleSpeech(_ text: String, _ final: Bool) {
        guard !session.answeredCurrentItem, !session.completed, scenePhase == .active else { return }
        if SpeechMatch.matches(text, target: prompt.text) {
            speech.cancel()
            _ = store.record(success: true, path: session.path, themeID: session.themeID, item: prompt.text)
            session.practiced += 1
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { session.answeredCurrentItem = true }
        } else if final, !SpeechMatch.normalized(text).isEmpty {
            speech.cancel()
            let changed = store.record(success: false, path: session.path, themeID: session.themeID, item: prompt.text)
            if changed {
                session.contentLevel = store.level(for: session.path)
                syllablePosition = 0
                feedback = "Let’s try a smaller step together."
            } else {
                feedback = session.path == .words
                    ? "Not quite. Tap the microphone and say “\(prompt.text)” again."
                    : "Let’s listen once more, then try together. Take your time."
            }
        }
    }
    private func markAssistedReading() {
        if session.path == .stories {
            guard !session.showingQuestions, !reading.paragraphComplete else { return }
            store.recordAssisted(path: .stories, themeID: session.themeID, item: activeParagraph)
            session.storyReading?.wordCount = ReadingAlignment.wordCount(in: activeParagraph)
            session.storyReading?.paragraphComplete = true
            session.practiced += 1
            return
        }
        guard !session.answeredCurrentItem else { return }
        store.recordAssisted(path: session.path, themeID: session.themeID, item: prompt.text)
        session.practiced += 1
        session.answeredCurrentItem = true
    }
    private func nextPrompt() {
        stopAudio()
        guard !session.completed else { return }
        if session.itemIndex >= 5 {
            // Skipping every prompt is an exploration, not a completed practice activity.
            if session.practiced > 0 { store.finish(&session) }
            else { dismiss() }
        } else {
            session.itemIndex += 1
            session.contentLevel = store.level(for: session.path)
            session.answeredCurrentItem = false
            syllablePosition = 0
            feedback = ""
            speech.message = nil
        }
    }
    private func previousParagraph() {
        stopAudio()
        if reading.paragraphIndex > 0 {
            session.storyReading = StoryReadingProgress(paragraphIndex: reading.paragraphIndex - 1)
        } else if session.sectionIndex > 0 {
            session.sectionIndex -= 1
            session.storyReading = StoryReadingProgress(paragraphIndex: paragraphs.count - 1)
        }
        feedback = ""
    }
    private func nextStoryStep() {
        guard reading.paragraphComplete, !session.showingQuestions else { return }
        stopAudio()
        feedback = ""
        session.advanceStoryParagraph(in: story)
    }
    private func answerQuestion(_ index: Int) {
        guard !session.answeredCurrentItem, !wrongOptions.contains(index) else { return }
        if index == question.answer {
            _ = store.record(success: true, path: session.path, themeID: session.themeID, item: question.text)
            session.answeredCurrentItem = true
            feedback = ""
        } else {
            wrongOptions.insert(index)
            let changed = store.record(success: false, path: session.path, themeID: session.themeID, item: question.text)
            if changed && store.level(for: session.path) < session.contentLevel {
                session.contentLevel = store.level(for: session.path)
                session.sectionIndex = 0
                session.storyReading = StoryReadingProgress()
                session.questionIndex = 0
                session.showingQuestions = false
                wrongOptions = []
                feedback = "Let’s read a simpler version together."
            } else { feedback = "Let’s look back at the story. You can try another answer." }
        }
    }
    private func nextQuestion() {
        guard session.answeredCurrentItem else { return }
        if session.questionIndex >= story.questions.count - 1 { store.finish(&session) }
        else {
            session.questionIndex += 1
            session.answeredCurrentItem = false
            wrongOptions = []
            feedback = ""
        }
    }
    private func stopAudio() { speech.cancel(); speaker.stop() }
}

private struct WateringTreeView: View {
    let listening: Bool
    let success: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var falling = false
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "cloud.fill").resizable().scaledToFit().frame(width: 125, height: 65)
            HStack(spacing: 22) {
                ForEach(0..<3) { index in
                    Image(systemName: "drop.fill")
                        .foregroundStyle(ReadLabStyle.sky)
                        .offset(y: falling && !reduceMotion ? 24 : 0)
                        .opacity(listening || success ? 1 : 0.15)
                        .animation(reduceMotion ? nil : .easeIn(duration: 1).repeatForever(autoreverses: false).delay(Double(index) * 0.2), value: falling)
                }
            }.frame(height: 42)
            Image(systemName: "tree.fill").resizable().scaledToFit().frame(width: 150, height: 125)
                .foregroundStyle(success ? Color(red: 0.35, green: 0.55, blue: 0.37) : ReadLabStyle.sky)
                .scaleEffect(success && !reduceMotion ? 1.15 : 0.92, anchor: .bottom)
                .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.65), value: success)
        }
        .onChange(of: listening) { _, value in falling = value && !reduceMotion }
        .onChange(of: reduceMotion) { _, value in falling = listening && !value }
        .accessibilityHidden(true)
    }
}
