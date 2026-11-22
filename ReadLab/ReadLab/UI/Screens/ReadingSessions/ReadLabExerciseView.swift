import SwiftUI
import AVFoundation

struct ReadLabExerciseView: View {
    let store: ReadLabStore
    @State private var session: PracticeSession
    @State private var speech = ReadLabSpeechService()
    @State private var speaker = ReadLabSpeaker()
    @State private var syllablePosition = 0.0
    @State private var feedback = ""
    @State private var storySpeechCursor = StorySpeechCursor()
    @State private var wrongOptions: Set<Int> = []
    @State private var adultCheckPresented = false
    @State private var turningPage: PageTurn?
    @State private var visible = false
    @State private var audioInterrupted = false
    @State private var audioRevision = 0
    @State private var preview: Preview?
    @State private var playedPreviewID: UUID?
    @State private var lastHearingPrompt: VoicePrompt?
    @State private var parrotReplyIndex: Int?

    private struct Preview: Equatable {
        let id = UUID()
        let text: String
    }

    private struct VoicePrompt: Equatable {
        let index: Int
        let level: Int
        let text: String
    }

    private enum AudioPlan: Equatable {
        case idle
        case story(level: Int, replay: Preview?)
        case word(VoicePrompt, hearFirst: Bool, replay: Preview?)
        case advance(index: Int, parrotReply: String?)
    }

    private struct AudioTaskID: Equatable {
        let plan: AudioPlan
        let revision: Int
    }

    private struct PageTurn: Identifiable {
        let id = UUID()
        let session: PracticeSession
        let forward: Bool
    }
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
    private var audioPlan: AudioPlan {
        guard visible, scenePhase == .active, !session.completed, !audioInterrupted, !adultCheckPresented else { return .idle }
        if session.path == .stories {
            guard !session.showingQuestions, !reading.paragraphComplete else { return .idle }
            return .story(level: session.contentLevel, replay: preview)
        }
        if session.answeredCurrentItem {
            let reply = parrotReplyIndex == session.itemIndex ? prompt.text : nil
            return .advance(index: session.itemIndex, parrotReply: reply)
        }
        let current = VoicePrompt(index: session.itemIndex, level: session.contentLevel, text: prompt.text)
        return .word(current, hearFirst: session.path == .hearing, replay: preview)
    }

    private var audioTaskID: AudioTaskID {
        AudioTaskID(plan: audioPlan, revision: audioRevision)
    }

    var body: some View {
        let currentAudio = audioTaskID
        GeometryReader { geo in
            let compact = geo.size.width < 800 || geo.size.width <= geo.size.height || typeSize.isAccessibilitySize
            ZStack {
                if session.path == .stories && !session.showingQuestions && !session.completed {
                    Color.white.ignoresSafeArea()
                } else {
                    ReadLabMissionArt(name: backgroundName).ignoresSafeArea()
                }
                if session.completed {
                    VStack {
                        header(compact: compact)
                        ScrollView { completion.padding(24).frame(maxWidth: .infinity) }
                    }
                    .padding(24)
                } else if session.path == .stories {
                    storyPractice(compact: compact)
                } else if compact {
                    ScrollView {
                        VStack(spacing: 18) {
                            header(compact: true)
                            ReadLabMissionArt(name: backgroundName)
                                .aspectRatio(1366.0 / 1024.0, contentMode: .fit)
                                .overlay(alignment: .trailing) {
                                    if session.path == .hearing { elephant.frame(width: 110).padding(.trailing, 20) }
                                }
                                .clipShape(.rect(cornerRadius: 24))
                            voicePractice(compact: true)
                                .padding(16)
                                .modifier(ReadLabPracticeCloud(cornerRadius: 22))
                        }
                        .padding(20)
                    }
                } else {
                    voiceScene(size: geo.size)
                }
            }
        }
        .foregroundStyle(ReadLabStyle.ink)
        .confirmationDialog("Read together", isPresented: $adultCheckPresented, titleVisibility: .visible) {
            Button("A grown-up checked this reading") { markAssistedReading() }
        } message: {
            Text("Continue after a grown-up listens to this reading. This practice won’t change the automatic difficulty.")
        }
        .onAppear { visible = true }
        .task(id: currentAudio) { await runAudio(currentAudio) }
        .task(id: storyAdvanceID) {
            guard session.path == .stories, !session.completed, !session.showingQuestions,
                  reading.paragraphComplete, scenePhase == .active else { return }
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            nextStoryStep()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.didBecomeInactiveNotification)) { notification in
            if let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
               context.source == .system {
                audioInterrupted = true
                stopAudio()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.resumptionRecommendationNotification)) { notification in
            if let context = notification.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext,
               context.recommendation == .shouldResume {
                audioInterrupted = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            if notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { stopAudio() }
        }
        .onChange(of: session) { old, value in
            store.update(value)
            animatePageTurn(from: old, to: value)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { audioInterrupted = false }
            else { stopAudio(); store.update(session) }
        }
        .onDisappear { leaveExercise() }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 18) {
            closeButton
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.title).readLabFont(compact ? 24 : 30, weight: .bold)
                Text(session.path.title).readLabFont(16, rounded: false)
            }
            Spacer(minLength: 0)
            if session.path == .hearing && !session.completed && !session.answeredCurrentItem { grownUpMenu }
            if !session.completed {
                Text(progressLabel).readLabFont(17, weight: .medium)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("exerciseProgress")
            }
        }
    }
    private var closeButton: some View {
        Button { leaveExercise(); dismiss() } label: {
            ReadLabMissionCircle(symbol: "xmark", size: 46)
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityLabel("Close activity")
        .accessibilityIdentifier("closeActivityButton")
    }

    private var progressLabel: String {
        if session.path != .stories { return "\(min(session.itemIndex + 1, 6)) of 6" }
        return session.showingQuestions
            ? "Question \(session.questionIndex + 1) of \(story.questions.count)"
            : "Page \(pageNumber(for: session)) of \(story.sections.reduce(0) { $0 + $1.count })"
    }

    private var backgroundName: String {
        switch session.path {
        case .words: "WordPracticeLandscape"
        case .hearing: "HearingLake"
        case .stories: "StoryQuizLandscape"
        }
    }

    private var elephant: some View {
        Image("Elephant").resizable().scaledToFit().accessibilityHidden(true)
    }

    private func voiceScene(size: CGSize) -> some View {
        ZStack {
            header(compact: false)
                .frame(width: size.width * 0.82)
                .position(x: size.width * 0.5, y: size.height * 0.09)
            ScrollView {
                voicePractice(compact: false)
                    .frame(minHeight: size.height * 0.45)
                    .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .frame(width: size.width * 0.49, height: size.height * 0.45)
            .modifier(ReadLabPracticeCloud(cornerRadius: 24))
            .position(x: size.width * 0.31, y: size.height * 0.47)

            if session.path == .hearing {
                elephant.frame(width: size.width * 0.20, height: size.height * 0.33)
                    .position(x: size.width * 0.82, y: size.height * 0.47)
            } else if session.answeredCurrentItem {
                Text(parrotReply)
                    .readLabFont(38, weight: .medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 18)
                    .frame(maxWidth: size.width * 0.26)
                    .background(.white, in: .rect(cornerRadius: 32))
                    .overlay(alignment: .bottomTrailing) {
                        ParrotSpeechTail().fill(.white).frame(width: 38, height: 26).offset(x: -16, y: 18)
                    }
                    .position(x: size.width * 0.64, y: size.height * 0.16)
                    .accessibilityLabel("The parrot repeats: \(prompt.text)")
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var parrotReply: String {
        prompt.text.last?.isPunctuation == true ? prompt.text : prompt.text + "!"
    }

    private func voicePractice(compact: Bool) -> some View {
        VStack(spacing: 12) {
            if session.path == .hearing {
                Button { requestPreview(prompt.text) } label: {
                    Text(prompt.text)
                        .readLabFont(compact ? 42 : 72, weight: .semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(session.answeredCurrentItem ? Color(red: 0.22, green: 0.43, blue: 0.28) : ReadLabStyle.ink)
                        .padding(8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Listen to \(prompt.text)")
                .accessibilityIdentifier("readingPrompt")
                .disabled(session.answeredCurrentItem)
            } else {
                syllableReader(compact: compact)
            }
            feedbackView
            if compact && session.path == .words && session.answeredCurrentItem {
                Label(parrotReply, systemImage: "bubble.left.fill")
                    .readLabFont(22, weight: .medium)
                    .accessibilityLabel("The parrot repeats: \(prompt.text)")
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }

    private var syllableParts: [String] {
        prompt.syllables.flatMap { $0.components(separatedBy: .whitespaces) }.filter { !$0.isEmpty }
    }
    /// The lens and its track share the measured width of the syllables.
    private func syllableReader(compact: Bool) -> some View {
        ReadLabSyllableExplorer(parts: syllableParts,
                               pointSize: compact ? 42 : 64,
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
        } else {
            voiceStatus
        }
    }

    @ViewBuilder private func storyPractice(compact: Bool) -> some View {
        if session.showingQuestions {
            VStack(spacing: 12) {
                quizHeader
                ScrollView { quiz(compact: compact) }.id(session.questionIndex)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { quizActions }
                    VStack(spacing: 12) { quizActions }
                }
            }
            .padding(.horizontal, compact ? 18 : 48)
            .padding(.vertical, 12)
        } else {
            GeometryReader { geo in
                ZStack {
                    storyPage(session, compact: compact, size: geo.size, played: true)
                    if let turningPage {
                        ReadLabTurningPage(forward: turningPage.forward, onFinish: {
                            if self.turningPage?.id == turningPage.id { self.turningPage = nil }
                        }) {
                            storyPage(turningPage.session, compact: compact, size: geo.size, played: false)
                        }
                        .id(turningPage.id)
                    }
                    VStack(spacing: 0) {
                        storyToolbar
                        Spacer(minLength: 0)
                        storyFooter
                    }
                    .padding(compact ? 10 : 17)
                }
            }
            .padding(compact ? 4 : 8)
        }
    }

    private var storyToolbar: some View {
        HStack(spacing: 10) {
            closeButton
            Text(theme.title)
                .readLabFont(19, weight: .semibold)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.9), in: Capsule())
            Spacer(minLength: 0)
            Text(progressLabel)
                .readLabFont(17, weight: .medium)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.9), in: Capsule())
                .accessibilityIdentifier("exerciseProgress")
            grownUpMenu
        }
    }

    private var storyFooter: some View {
        VStack(spacing: 4) {
            if reading.paragraphComplete {
                Label("Lovely reading!", systemImage: "checkmark.seal.fill")
                    .readLabFont(17, weight: .semibold)
            } else {
                voiceStatus
            }
            Text("\(reading.wordCount) of \(StoryText.wordCount(in: activeParagraph)) words read")
                .readLabFont(14, weight: .medium)
                .accessibilityIdentifier("storyReadingProgress")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(.white.opacity(0.94), in: .rect(cornerRadius: 16))
        .frame(maxWidth: 800)
    }

    private func pageNumber(for value: PracticeSession) -> Int {
        story.sections.prefix(value.sectionIndex).reduce(0) { $0 + $1.count } + (value.storyReading?.paragraphIndex ?? 0) + 1
    }

    private func storyPage(_ value: PracticeSession, compact: Bool, size: CGSize, played: Bool) -> some View {
        let page = pageNumber(for: value)
        let index = value.storyReading?.paragraphIndex ?? 0
        let passage = story.sections[min(value.sectionIndex, story.sections.count - 1)]
        let paragraph = passage[min(index, passage.count - 1)]
        let count = played ? value.storyReading?.wordCount ?? 0 : StoryText.wordCount(in: paragraph)
        let margin: CGFloat = compact ? 9 : 16
        let width = max(1, size.width - margin * 2)
        let height = max(1, size.height - margin * 2)
        let art = ReadLabIllustratedStories.artwork(for: theme, page: page)
        return ZStack(alignment: .top) {
            ReadLabMissionArt(name: art)
                .aspectRatio(contentMode: compact ? .fit : .fill)
                .frame(width: width, height: height)
                .clipped()
            ScrollView {
                Button { requestPreview(paragraph) } label: {
                    Text(StoryText.highlighted(paragraph, through: count))
                        .readLabFont(compact ? 27 : 54, weight: .medium)
                        .multilineTextAlignment(.center)
                        .padding(compact ? 12 : 22)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.90), in: .rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Listen to this paragraph")
                .accessibilityValue("\(count) of \(StoryText.wordCount(in: paragraph)) words read")
                .accessibilityIdentifier("storyParagraph\(index)")
                .padding(.horizontal, compact ? 6 : 42)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: 1200)
            .padding(.top, compact ? 64 : 78)
            .padding(.bottom, compact ? 100 : 92)
        }
        .frame(width: width, height: height)
        .modifier(ReadLabBookPaper(margin: margin, paper: .white))
    }

    private func animatePageTurn(from old: PracticeSession, to current: PracticeSession) {
        guard !reduceMotion, old.path == .stories, !old.showingQuestions, !current.completed,
              old.contentLevel == current.contentLevel else { return }
        let oldPage = pageNumber(for: old)
        let newPage = pageNumber(for: current)
        guard !current.showingQuestions else { turningPage = nil; return }
        guard oldPage != newPage else { return }
        turningPage = PageTurn(session: old, forward: current.showingQuestions || newPage > oldPage)
    }

    private var quizHeader: some View {
        ZStack {
            HStack(spacing: 12) {
                ForEach(story.questions.indices, id: \.self) { index in
                    Circle()
                        .fill(index == session.questionIndex ? ReadLabStyle.ink : ReadLabStyle.ink.opacity(0.26))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(progressLabel)
            .accessibilityIdentifier("exerciseProgress")
            HStack {
                closeButton
                Spacer()
            }
        }
        .frame(maxWidth: 900)
    }

    private func quiz(compact: Bool) -> some View {
        VStack(spacing: compact ? 18 : 28) {
            Text(question.text)
                .readLabFont(compact ? 33 : 57, weight: .medium)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, compact ? 10 : 28)
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                let correct = session.answeredCurrentItem && index == question.answer
                Button { answerQuestion(index) } label: {
                    HStack(spacing: 16) {
                        Text(option).readLabFont(compact ? 23 : 30, weight: .semibold)
                        Spacer()
                        Image(systemName: correct ? "checkmark.circle.fill" : (wrongOptions.contains(index) ? "arrow.counterclockwise.circle.fill" : "circle.fill"))
                            .font(.system(size: compact ? 28 : 38))
                            .foregroundStyle(correct ? Color.green : ReadLabStyle.muted)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, compact ? 16 : 42)
                    .padding(.vertical, 16)
                    .frame(minHeight: compact ? 58 : 88)
                    .background(correct ? ReadLabStyle.sky : .white, in: .rect(cornerRadius: 25))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 3)
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
        }
        .frame(maxWidth: 840)
        .padding(.horizontal, 8)
        .padding(.top, compact ? 12 : 54)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
    }

    private var grownUpMenu: some View {
        Menu {
            if session.path == .stories && pageNumber(for: session) > 1 {
                Button("Previous Page", systemImage: "chevron.left") { previousParagraph() }
            }
            Button("Practise with a Grown-up", systemImage: "person.2") {
                stopAudio()
                adultCheckPresented = true
            }
        } label: {
            ReadLabMissionCircle(symbol: "ellipsis", size: 44)
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder private var quizActions: some View {
        Button("Read Again", systemImage: "book") {
            preview = nil
            feedback = ""
            wrongOptions = []
            session.showingQuestions = false
            session.sectionIndex = 0
            session.questionIndex = 0
            session.answeredCurrentItem = false
            session.storyReading = StoryReadingProgress()
        }.buttonStyle(.bordered).controlSize(.large)
        ReadLabActionButton(title: session.questionIndex == story.questions.count - 1 ? "Finish Story" : "Next Question",
                            action: nextQuestion, enabled: session.answeredCurrentItem)
    }

    @ViewBuilder private var voiceStatus: some View {
        if audioInterrupted {
            Button("Resume listening") { audioInterrupted = false }
                .buttonStyle(.bordered)
        } else if speaker.isSpeaking {
            Label("Listen first…", systemImage: "speaker.wave.2")
                .readLabFont(18, weight: .medium)
                .accessibilityIdentifier("practiceListeningState")
        } else if let message = speech.message {
            VStack(spacing: 6) {
                Text(message).readLabFont(17, rounded: false)
                if speech.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url).buttonStyle(.bordered)
                } else if speech.canRetry {
                    Button("Try listening again") { audioRevision += 1 }.buttonStyle(.bordered)
                }
                if session.path == .words { grownUpMenu }
            }
            .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 4) {
                if !feedback.isEmpty { Text(feedback).readLabFont(17, weight: .medium) }
                let listening = speech.isListening || speech.isFinishing
                Label(speech.isFinishing ? "Checking your reading…" : (speech.isListening ? "I’m listening…" : "Getting ready…"),
                      systemImage: listening ? "waveform" : "ear")
                    .readLabFont(18, weight: .medium)
                    .accessibilityIdentifier("practiceListeningState")
                if listening && !speech.transcript.isEmpty {
                    Text(verbatim: speech.transcript)
                        .readLabFont(16, rounded: false)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .accessibilityLabel("Heard: \(speech.transcript)")
                        .accessibilityIdentifier("liveSpeechTranscript")
                }
            }
            .multilineTextAlignment(.center)
        }
    }

    private func runAudio(_ key: AudioTaskID) async {
        guard !Task.isCancelled, key == audioTaskID else { return }
        stopAudio()
        switch key.plan {
        case .idle:
            return
        case .advance(_, let reply):
            // Finish the parrot’s reply before changing the prompt and restarting capture.
            if let reply { _ = await speaker.speak(reply, pitch: 1.75) }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, key == audioTaskID else { return }
            nextPrompt()
        case .story(_, let replay):
            await playReplayIfNeeded(replay)
            guard !Task.isCancelled, key == audioTaskID else { return }
            await listenAutomatically(key: key, target: nil)
        case .word(let word, let hearFirst, let replay):
            if let replay, replay.id != playedPreviewID {
                await playReplayIfNeeded(replay)
                guard !Task.isCancelled, key == audioTaskID else { return }
                if hearFirst { lastHearingPrompt = word }
            } else if hearFirst && lastHearingPrompt != word {
                await playBeforeListening(word.text)
                guard !Task.isCancelled, key == audioTaskID else { return }
                lastHearingPrompt = word
            }
            await listenAutomatically(key: key, target: word.text)
        }
    }

    private func listenAutomatically(key: AudioTaskID, target: String?) async {
        var shortAttempts = 0
        let clock = ContinuousClock()
        while !Task.isCancelled && key == audioTaskID {
            let start = clock.now
            if let target {
                await speech.listen(target: target, onResult: handleSpeech)
            } else {
                storySpeechCursor = StorySpeechCursor()
                await speech.listen(onNewSegment: { storySpeechCursor = StorySpeechCursor() }, onResult: handleStorySpeech)
            }
            guard !Task.isCancelled, key == audioTaskID, speech.message == nil else { return }
            // Renew after silence. Avoid spinning if the audio route repeatedly stops immediately.
            shortAttempts = clock.now - start < .seconds(1) ? shortAttempts + 1 : 0
            if shortAttempts >= 3 {
                speech.reportInterruption()
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func playReplayIfNeeded(_ replay: Preview?) async {
        guard let replay, replay.id != playedPreviewID else { return }
        await playBeforeListening(replay.text)
        if !Task.isCancelled { playedPreviewID = replay.id }
    }

    private func playBeforeListening(_ text: String) async {
        // Capture has stopped. Leave a brief gap after playback for the device’s speaker tail.
        _ = await speaker.speak(text)
        try? await Task.sleep(for: .milliseconds(300))
    }

    private func handleStorySpeech(_ text: String, _: Bool, _ alternatives: SpeechWordAlternatives) {
        guard scenePhase == .active else { return }
        var cursor = storySpeechCursor
        let completedParagraphs = session.readStoryTranscript(text, cursor: &cursor, in: story, alternatives: alternatives)
        storySpeechCursor = cursor
        for paragraph in completedParagraphs {
            _ = store.record(success: true, path: .stories, themeID: session.themeID, item: paragraph)
        }
        if session.showingQuestions { speech.cancel() }
    }

    private func requestPreview(_ text: String) {
        stopAudio()
        feedback = ""
        preview = Preview(text: text)
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

    private func handleSpeech(_ text: String, _ final: Bool, _: SpeechWordAlternatives) {
        guard !session.answeredCurrentItem, !session.completed, scenePhase == .active else { return }
        if SpeechMatch.matches(text, target: prompt.text) {
            speech.cancel()
            _ = store.record(success: true, path: session.path, themeID: session.themeID, item: prompt.text)
            session.practiced += 1
            if session.path == .words { parrotReplyIndex = session.itemIndex }
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
                    ? "Try saying “\(prompt.text)” again."
                    : "Take your time. Tap the word if you’d like to hear it again."
            }
        }
    }
    private func markAssistedReading() {
        if session.path == .stories {
            guard !session.showingQuestions, !reading.paragraphComplete else { return }
            store.recordAssisted(path: .stories, themeID: session.themeID, item: activeParagraph)
            session.storyReading?.wordCount = StoryText.wordCount(in: activeParagraph)
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
        preview = nil
        parrotReplyIndex = nil
        guard !session.completed else { return }
        if session.itemIndex >= 5 {
            // Skipping every prompt is an exploration, not a completed practice activity.
            if session.practiced > 0 { store.finish(&session) }
            else { leaveExercise(); dismiss() }
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
        preview = nil
        audioRevision += 1
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
    private func leaveExercise() {
        visible = false
        stopAudio()
        store.update(session)
    }

    private func stopAudio() { speech.cancel(); speaker.stop() }
}

private struct ParrotSpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .zero)
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                              control: CGPoint(x: rect.midX, y: rect.maxY * 0.7))
            path.addLine(to: CGPoint(x: rect.width * 0.66, y: 0))
            path.closeSubpath()
        }
    }
}
