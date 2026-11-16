import SwiftUI

struct ReadLabHomeView: View {
    @Bindable var store: ReadLabStore
    @State private var suggestionIndex = 0
    @State private var settingsPresented = false
    @State private var activeSession: PracticeSession?
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
            Text(path.title + ":")
                .readLabFont(compact ? 52 : 70, weight: .medium)
                .padding(.trailing, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    Button("Account", systemImage: "person.crop.circle") { settingsPresented = true }
                        .labelStyle(.iconOnly)
                        .font(.system(size: 40))
                        .buttonStyle(.borderless)
                        .frame(width: 52, height: 64)
                        .accessibilityIdentifier("accountButton")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(path.question)
                .readLabFont(compact ? 52 : 70, weight: .medium)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .foregroundStyle(ReadLabStyle.ink)
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
                Text(suggestion.title).readLabFont(35, weight: .semibold)
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
                .background(Color(white: 0.52), in: Capsule())
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityHint("Choose another collection")
    }
    private var startButton: some View {
        Button { begin(suggestion) } label: {
            Text(path == .hearing ? "Let’s start hearing" : "Let’s start read")
                .readLabFont(24, weight: .bold)
                .foregroundStyle(ReadLabStyle.ink)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(ReadLabStyle.blue, in: Capsule())
        }.buttonStyle(ReadLabTapStyle())
    }
    private var mascot: some View {
        Image(path.mascot).resizable().scaledToFit()
            .frame(width: path == .words ? 240 : 360, height: 360)
            .accessibilityHidden(true)
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
                    Text(theme.title).readLabFont(25, weight: .semibold)
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
        return session.showingQuestions ? 0.75 + 0.25 * Double(session.questionIndex) / Double(story.questions.count) : Double(session.sectionIndex) / Double(story.sections.count + 1)
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
