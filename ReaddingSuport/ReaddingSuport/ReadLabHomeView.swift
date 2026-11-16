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
        GeometryReader { geo in
            let wide = geo.size.width >= 850 && !typeSize.isAccessibilitySize
            ZStack {
                ReadLabPastelBackground(path: path)
                ScrollView {
                    VStack(alignment: .leading, spacing: wide ? 36 : 28) {
                        header(compact: !wide)
                        if wide {
                            HStack(alignment: .bottom, spacing: 42) {
                                suggestionCard(imageHeight: min(280, max(190, geo.size.height * 0.29)))
                                    .frame(maxWidth: .infinity)
                                VStack(spacing: 28) {
                                    mascot.frame(height: min(300, geo.size.height * 0.34))
                                    resumeCard
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            suggestionCard(imageHeight: min(280, geo.size.width * 0.5))
                            mascot.frame(height: 170).frame(maxWidth: .infinity)
                            resumeCard
                        }
                    }
                    .frame(maxWidth: 1400)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, wide ? 64 : 24)
                    .padding(.vertical, wide ? 40 : 22)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onChange(of: path) { _, _ in suggestionIndex = 0 }
        .sheet(isPresented: $settingsPresented) {
            ReadLabSettingsView(store: store)
                .presentationSizing(.form)
        }
        .fullScreenCover(item: $activeSession) { session in
            ReadLabExerciseView(store: store, initialSession: session)
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(path.title + ":").readLabFont(compact ? 30 : 42, weight: .medium)
                Text(path.question).readLabFont(compact ? 37 : 52, weight: .medium)
                    .fixedSize(horizontal: false, vertical: true)
            }.accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button("Account", systemImage: "person.crop.circle") { settingsPresented = true }
                .labelStyle(.iconOnly)
                .font(.system(size: 30))
                .buttonStyle(.borderless)
                .frame(minWidth: 52, minHeight: 52)
                .accessibilityIdentifier("accountButton")
        }.foregroundStyle(ReadLabStyle.ink)
    }

    private func suggestionCard(imageHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(suggestion.cover).resizable().scaledToFill()
                .frame(height: imageHeight).clipped()
                .overlay(alignment: .topLeading) {
                    Text("Daily discovery").readLabFont(16, weight: .semibold)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(ReadLabStyle.sand, in: Capsule())
                        .padding(20)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 18) {
                Text(suggestion.title).readLabFont(32, weight: .bold)
                Text(suggestion.detail).readLabFont(22, weight: .light, rounded: false)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { shuffle; startButton }
                    VStack(alignment: .leading, spacing: 16) { shuffle; startButton }
                }.padding(.top, 12)
            }.padding(28)
        }
        .foregroundStyle(ReadLabStyle.ink)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: ReadLabStyle.ink.opacity(0.18), radius: 6, y: 5)
        .id(suggestion.id)
        .transition(.opacity)
    }

    private var shuffle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { suggestionIndex = (suggestionIndex + 1) % themes.count }
        } label: {
            Label("Shuffle", systemImage: "shuffle")
                .readLabFont(20, weight: .semibold)
                .padding(.horizontal, 20).padding(.vertical, 18)
                .background(Color(.systemGray5), in: Capsule())
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityHint("Choose another collection")
    }
    private var startButton: some View {
        ReadLabActionButton(title: path == .hearing ? "Let’s Hear" : "Let’s Read") { begin(suggestion) }
    }
    private var mascot: some View {
        Image(path.mascot).resizable().scaledToFit()
            .padding(16).accessibilityHidden(true)
    }
    private var resumeCard: some View {
        let theme = savedSession.map { ReadingTheme.find($0.themeID) } ?? themes[(suggestionIndex + 1) % themes.count]
        return Button {
            if let savedSession { activeSession = savedSession } else { begin(theme) }
        } label: {
            HStack(spacing: 20) {
                Image(theme.cover).resizable().scaledToFill()
                    .frame(width: 115, height: 130).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 10) {
                    Text(savedSession == nil ? "Another little adventure" : "Resume your last session")
                        .readLabFont(17, rounded: false)
                    Text(theme.title).readLabFont(25, weight: .bold)
                    if let savedSession {
                        ProgressView(value: sessionProgress(savedSession))
                            .tint(Color(red: 0.32, green: 0.48, blue: 0.33))
                            .accessibilityLabel("Session progress")
                    } else {
                        Label("Explore", systemImage: "arrow.right").readLabFont(17, weight: .medium)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(ReadLabStyle.ink)
            .multilineTextAlignment(.leading)
            .padding(12)
            .readLabCard()
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityIdentifier("resumeSessionButton")
    }
    private func sessionProgress(_ session: PracticeSession) -> Double {
        guard session.path == .stories else { return session.progress }
        let story = ReadLabLibrary.story(theme: session.themeID, level: session.contentLevel)
        return session.showingQuestions ? 0.75 : Double(session.sectionIndex) / Double(story.sections.count + 1)
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
