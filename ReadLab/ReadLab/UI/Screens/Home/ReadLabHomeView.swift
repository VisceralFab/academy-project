import SwiftUI

struct ReadLabHomeView: View {
    @Bindable var store: ReadLabStore
    @State private var suggestionIndex = 0
    @State private var settingsPresented = false
    @State private var activeSession: PracticeSession?
    @Environment(\.readLabAudio) private var audio
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var path: ReadingPath { store.data.selectedPath }
    private var themes: [ReadingTheme] { ReadingTheme.themes(for: path) }
    private var suggestion: ReadingTheme { themes[suggestionIndex % themes.count] }
    private var savedSession: PracticeSession? { store.session(for: path).flatMap { $0.completed ? nil : $0 } }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 1100 && !typeSize.isAccessibilitySize
            let inset: CGFloat = wide ? 67 : 28
            let available = geometry.size.width - inset - (wide ? 60 : inset)
            // 1366 × 1024 reference: 655 pt feature, 50 pt gap, 534 pt resume column.
            let scale = min(1, available / 1239)
            ZStack {
                ReadLabPastelBackground(path: path)
                ScrollView {
                    VStack(alignment: .leading, spacing: wide ? 72 : 40) {
                        header(compact: !wide)
                        if wide {
                            HStack(alignment: .bottom, spacing: 50 * scale) {
                                suggestionCard(width: 655 * scale, height: 600 * scale, imageHeight: 309 * scale)
                                VStack(spacing: 0) {
                                    mascot.frame(maxWidth: .infinity).frame(height: 430 * scale)
                                    Spacer(minLength: 0)
                                    resumeCard(width: 534 * scale, compact: false)
                                }
                                .frame(width: 534 * scale, height: 600 * scale)
                            }
                        } else {
                            suggestionCard(width: available, height: nil, imageHeight: min(340, available * 0.48))
                            mascot.frame(maxWidth: .infinity).frame(height: 280)
                            resumeCard(width: available, compact: true)
                        }
                    }
                    .frame(maxWidth: 1239, alignment: .leading)
                    .padding(.leading, inset)
                    .padding(.trailing, wide ? 60 : inset)
                    .padding(.top, wide ? 36 : 28)
                    .padding(.bottom, 54)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onChange(of: activeSession?.id) { _, id in audio?.setScene(id == nil ? .home : .practice) }
        .onChange(of: path) { _, _ in suggestionIndex = 0 }
        .sheet(isPresented: $settingsPresented) {
            ReadLabSettingsView(store: store).presentationSizing(.form)
        }
        .fullScreenCover(item: $activeSession) { session in
            ReadLabExerciseView(store: store, initialSession: session)
        }
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(path.title)
                .readLabFont(compact ? 52 : 70, weight: .bold)
                .padding(.trailing, 84)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) { accountButton }
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(path.question)
                .readLabFont(compact ? 52 : 70, weight: .medium)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .foregroundStyle(ReadLabStyle.ink)
    }

    /// A filled, high-contrast avatar so the Account entry point stands out on the pastel background.
    private var accountButton: some View {
        Button { settingsPresented = true } label: {
            Image(systemName: "person.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                .frame(width: 68, height: 68)
                // Top-lit gradient + inner highlight give the button a raised, tactile look.
                .background(
                    LinearGradient(colors: [Color(red: 0.30, green: 0.63, blue: 0.86), ReadLabStyle.actionFill],
                                   startPoint: .top, endPoint: .bottom),
                    in: Circle())
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 2).padding(4)
                }
                .overlay { Circle().strokeBorder(.white, lineWidth: 4) }
                // Two layered shadows: a tight contact shadow and a soft ambient one.
                .shadow(color: ReadLabStyle.ink.opacity(0.35), radius: 2, y: 2)
                .shadow(color: ReadLabStyle.ink.opacity(0.30), radius: 14, y: 9)
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityLabel("Account")
        .accessibilityHint("Profile, settings and performance report")
        .accessibilityIdentifier("accountButton")
    }

    private func suggestionCard(width: CGFloat, height: CGFloat?, imageHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(suggestion.cover).resizable().scaledToFill()
                .frame(width: width, height: imageHeight).clipped()
                .overlay(alignment: .topLeading) {
                    Text("Daily suggest").readLabFont(13, weight: .medium)
                        .padding(.horizontal, 22).padding(.vertical, 8)
                        .background(ReadLabStyle.sand, in: Capsule()).padding(22)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(suggestion.title).readLabFont(35, weight: .bold)
                Text(suggestion.detail).readLabFont(25, weight: .light, rounded: false)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                Spacer(minLength: 32)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 30) { shuffle; startButton.frame(maxWidth: .infinity) }
                    VStack(alignment: .leading, spacing: 16) { shuffle; startButton }
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 44)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: width, height: height)
        .foregroundStyle(ReadLabStyle.ink)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: ReadLabStyle.ink.opacity(0.20), radius: 6, y: 5)
        .id(suggestion.id)
        .transition(.opacity)
    }

    private var shuffle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { suggestionIndex = (suggestionIndex + 1) % themes.count }
        } label: {
            Label("Shuffle", systemImage: "shuffle")
                .readLabFont(24, weight: .bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 26)
                .frame(minHeight: 62)
                .background(ReadLabStyle.secondaryFill, in: Capsule())
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityHint("Choose another collection")
    }
    private var startButton: some View {
        Button { begin(suggestion) } label: {
            Text(path == .hearing ? "Let’s start hearing" : "Let’s start read")
                .readLabFont(24, weight: .bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(ReadLabStyle.actionFill, in: Capsule())
                .shadow(color: ReadLabStyle.actionFill.opacity(0.30), radius: 6, y: 3)
        }.buttonStyle(ReadLabTapStyle())
    }
    private var mascot: some View {
        Button { audio?.playAnimal(for: path, mascot: true) } label: {
            Image(path.mascot).resizable().scaledToFit()
                .frame(width: path == .words ? 240 : 360, height: 360)
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityLabel("Play \(path.mascot.lowercased()) sound")
        .accessibilityIdentifier("mascotButton")
    }
    private func resumeCard(width: CGFloat, compact: Bool) -> some View {
        let theme = savedSession.map { ReadingTheme.find($0.themeID) } ?? themes[(suggestionIndex + 1) % themes.count]
        return Button {
            if let savedSession { activeSession = savedSession } else { begin(theme) }
        } label: {
            HStack(spacing: 32) {
                Image(theme.cover).resizable().scaledToFill()
                    .frame(width: compact ? 125 : width * 125 / 534, height: 105).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(resumeTitle).readLabFont(15, weight: .light, rounded: false)
                    Text(theme.title).readLabFont(25, weight: .bold)
                    if let savedSession {
                        ProgressView(value: sessionProgress(savedSession))
                            .tint(Color(red: 0.44, green: 0.59, blue: 0.42))
                            .accessibilityLabel("Session progress")
                            .padding(.top, 5)
                    } else {
                        Label("Explore", systemImage: "arrow.right").readLabFont(15, weight: .medium)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 24)
            }
            .frame(width: width, alignment: .leading)
            .foregroundStyle(ReadLabStyle.ink)
            .multilineTextAlignment(.leading)
            .readLabCard()
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityIdentifier("resumeSessionButton")
    }
    private var resumeTitle: String {
        guard savedSession != nil else { return "Another little adventure" }
        switch path {
        case .hearing: return "Resume your last hearing"
        case .words: return "Resume your last session"
        case .stories: return "Resume your last reading"
        }
    }
    private func sessionProgress(_ session: PracticeSession) -> Double {
        guard session.path == .stories else { return session.progress }
        let story = ReadLabLibrary.story(theme: session.themeID, level: session.contentLevel)
        if session.showingQuestions {
            return 0.75 + 0.25 * Double(session.questionIndex) / Double(story.questions.count)
        }
        let section = session.storyReading == nil ? story.sectionIndex(forLegacySection: session.sectionIndex) : session.sectionIndex
        let paragraphs = story.sections[min(section, story.sections.count - 1)]
        let reading = session.storyReading ?? StoryReadingProgress()
        let paragraph = min(reading.paragraphIndex, paragraphs.count - 1)
        let words = max(1, StoryText.wordCount(in: paragraphs[paragraph]))
        let fraction = (Double(paragraph) + min(1, Double(reading.wordCount) / Double(words))) / Double(paragraphs.count)
        return 0.75 * (Double(section) + fraction) / Double(story.sections.count)
    }
    private func begin(_ theme: ReadingTheme) {
        if let saved = savedSession, saved.themeID == theme.id { activeSession = saved }
        else { activeSession = store.start(path: path, theme: theme) }
    }
}

#Preview("First words · landscape", traits: .fixedLayout(width: 1366, height: 1024)) {
    let store = ReadLabStore(defaults: UserDefaults(suiteName: "home.preview.\(UUID())")!)
    store.data.hasOnboarded = true
    store.data.selectedPath = .words
    return ContentView(store: store)
}
