import SwiftUI

struct ReadLabExerciseView: View {
    let store: ReadLabStore
    @State private var session: PracticeSession
    @State private var speech = ReadLabSpeechService()
    @State private var speaker = ReadLabSpeaker()
    @State private var zoom = 0.35
    @State private var syllablePosition = 0.0
    @State private var feedback = ""
    @State private var wrongOptions: Set<Int> = []
    @State private var adultCheckPresented = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    init(store: ReadLabStore, initialSession: PracticeSession) {
        self.store = store
        _session = State(initialValue: initialSession)
    }
    private var theme: ReadingTheme { ReadingTheme.find(session.themeID) }
    private var prompts: [ReadingPrompt] { ReadLabLibrary.prompts(theme: session.themeID, level: session.contentLevel) }
    private var prompt: ReadingPrompt { prompts[min(session.itemIndex, prompts.count - 1)] }
    private var story: ReadingStory { ReadLabLibrary.story(theme: session.themeID, level: session.contentLevel) }
    private var question: StoryQuestion { story.questions[min(session.questionIndex, story.questions.count - 1)] }

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
                Text(theme.title).readLabFont(compact ? 24 : 30, weight: .semibold)
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
                Text(prompt.text)
                    .readLabFont(compact ? 42 : 58, weight: .semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(session.answeredCurrentItem ? Color(red: 0.22, green: 0.43, blue: 0.28) : ReadLabStyle.ink)
                    .accessibilityIdentifier("readingPrompt")
                WateringTreeView(listening: speech.isListening, success: session.answeredCurrentItem)
                    .frame(height: compact ? 210 : 250)
            } else {
                syllableReader(compact: compact)
                VStack(spacing: 10) {
                    Text("Slide to explore each syllable").readLabFont(17, rounded: false)
                    Slider(value: $syllablePosition, in: 0...Double(max(1, syllableParts.count - 1)), step: 1)
                        .accessibilityLabel("Syllable focus")
                        .accessibilityValue(syllableParts[min(Int(syllablePosition), syllableParts.count - 1)])
                }.frame(maxWidth: 650)
            }
            feedbackView
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: session.answeredCurrentItem)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: syllablePosition)
    }

    private var syllableParts: [String] {
        prompt.syllables.flatMap { $0.components(separatedBy: .whitespaces) }.filter { !$0.isEmpty }
    }
    private func syllableReader(compact: Bool) -> some View {
        FlowingSyllables(spacing: compact ? 8 : 12) {
            ForEach(Array(syllableParts.enumerated()), id: \.offset) { index, syllable in
                let focused = Int(syllablePosition) == index
                Text(syllable)
                    .readLabFont((compact ? 35 : 48) + zoom * 25 + (focused ? 12 : 0), weight: .semibold)
                    .padding(.horizontal, 10).padding(.vertical, 14)
                    .background(session.answeredCurrentItem ? Color.green.opacity(0.18) : (focused ? ReadLabStyle.sky.opacity(0.5) : .clear), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(alignment: .bottom) {
                        Capsule().fill(focused ? ReadLabStyle.ink : ReadLabStyle.ink.opacity(0.16)).frame(height: focused ? 4 : 2)
                    }
                    .onTapGesture { syllablePosition = Double(index) }
            }
        }
        .frame(minHeight: compact ? 180 : 240)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prompt.text)
        .accessibilityIdentifier("readingPrompt")
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
            Text("Tap the speaker to listen, then the microphone to read aloud.")
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
                ForEach(Array(story.sections[min(session.sectionIndex, story.sections.count - 1)].enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph).readLabFont(24 + zoom * 22)
                        .lineSpacing(12)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("storyParagraph")
                }
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
                HStack(spacing: 14) {
                    Button("Previous", systemImage: "chevron.left") { moveSection(-1) }
                        .disabled(session.sectionIndex == 0).buttonStyle(.bordered).controlSize(.large)
                    Button("Listen", systemImage: "speaker.wave.2.fill") {
                        speech.cancel()
                        speaker.speak(story.sections[session.sectionIndex].joined(separator: " "))
                    }.buttonStyle(.bordered).controlSize(.large)
                }
                ReadLabActionButton(title: session.sectionIndex == story.sections.count - 1 ? "Story Questions" : "Next Section") { nextStoryStep() }
            } else {
                Button("Read Again", systemImage: "book") {
                    feedback = ""; wrongOptions = []; session.showingQuestions = false; session.sectionIndex = 0
                }.buttonStyle(.bordered).controlSize(.large)
                ReadLabActionButton(title: session.questionIndex == story.questions.count - 1 ? "Finish Story" : "Next Question", action: nextQuestion, enabled: session.answeredCurrentItem)
            }
        } else {
            HStack(spacing: 14) {
                Button("Listen", systemImage: "speaker.wave.2.fill") {
                    speech.cancel(); speaker.speak(prompt.text)
                }.buttonStyle(.bordered).controlSize(.large)
                Button {
                    speaker.stop()
                    if speech.isListening { speech.finishListening() }
                    else { Task { await speech.start(target: prompt.text, onResult: handleSpeech) } }
                } label: {
                    Label(speech.isListening ? "Finish" : "Read Aloud", systemImage: speech.isListening ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .tint(ReadLabStyle.ink)
                .foregroundStyle(.white)
                .disabled(session.answeredCurrentItem || speech.isPreparing)
                .accessibilityIdentifier("microphoneButton")
            }
            if session.answeredCurrentItem {
                ReadLabActionButton(title: session.itemIndex == 5 ? "Finish" : "Next Word", action: nextPrompt)
            } else {
                Menu {
                    Button("Practise with a Grown-up", systemImage: "person.2") { stopAudio(); adultCheckPresented = true }
                    Button("Try Another Word", systemImage: "arrow.right") { nextPrompt() }
                } label: { Label("More", systemImage: "ellipsis.circle") }
                .buttonStyle(.bordered).controlSize(.large)
            }
        }
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
            _ = store.record(success: true, path: session.path)
            session.practiced += 1
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { session.answeredCurrentItem = true }
        } else if final, !SpeechMatch.normalized(text).isEmpty {
            speech.cancel()
            let changed = store.record(success: false, path: session.path)
            if changed {
                session.contentLevel = store.level(for: session.path)
                syllablePosition = 0
                feedback = "Let’s try a smaller step together."
            } else { feedback = "Let’s listen once more, then try together. Take your time." }
        }
    }
    private func markAssistedReading() {
        guard !session.answeredCurrentItem else { return }
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
    private func moveSection(_ delta: Int) {
        stopAudio()
        session.sectionIndex = min(story.sections.count - 1, max(0, session.sectionIndex + delta))
        feedback = ""
    }
    private func nextStoryStep() {
        stopAudio()
        feedback = ""
        if session.sectionIndex < story.sections.count - 1 { session.sectionIndex += 1 }
        else { session.showingQuestions = true }
    }
    private func answerQuestion(_ index: Int) {
        guard !session.answeredCurrentItem, !wrongOptions.contains(index) else { return }
        if index == question.answer {
            _ = store.record(success: true, path: session.path)
            session.answeredCurrentItem = true
            feedback = ""
        } else {
            wrongOptions.insert(index)
            let changed = store.record(success: false, path: session.path)
            if changed {
                session.contentLevel = store.level(for: session.path)
                session.sectionIndex = 0
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

/// A wrapping, centered line of syllables that remains usable at large text sizes.
private struct FlowingSyllables: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? 700, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(width: bounds.width, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var points = [CGPoint](repeating: .zero, count: subviews.count)
        var rows: [[Int]] = [[]]
        var rowWidth: CGFloat = 0
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        for i in sizes.indices {
            if rowWidth > 0 && rowWidth + sizes[i].width > width { rows.append([]); rowWidth = 0 }
            rows[rows.count - 1].append(i)
            rowWidth += sizes[i].width + spacing
        }
        var y: CGFloat = 0
        for row in rows where !row.isEmpty {
            let total = row.reduce(CGFloat(0)) { $0 + sizes[$1].width } + spacing * CGFloat(row.count - 1)
            let height = row.map { sizes[$0].height }.max() ?? 0
            var x = max(0, (width - total) / 2)
            for i in row { points[i] = CGPoint(x: x, y: y + (height - sizes[i].height) / 2); x += sizes[i].width + spacing }
            y += height + spacing
        }
        return (CGSize(width: width, height: max(0, y - spacing)), points)
    }
}
