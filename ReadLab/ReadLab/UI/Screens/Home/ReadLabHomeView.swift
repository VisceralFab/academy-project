import SwiftUI

struct ReadLabHomeView: View {
    @Bindable var store: ReadLabStore
    @State private var suggestionIndex = 0
    @State private var settingsPresented = false
    @State private var activeSession: PracticeSession?
    @State private var suggestedActionSize: CGSize = .zero
    @Environment(\.readLabAudio) private var audio
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var path: ReadingPath { store.data.selectedPath }
    private var themes: [ReadingTheme] {
        let list = ReadingTheme.themes(for: path)
        return path == .words ? Array(list.reversed()) : list
    }
    private var suggestion: ReadingTheme { themes[suggestionIndex % themes.count] }
    private var savedSession: PracticeSession? { store.session(for: path).flatMap { $0.completed ? nil : $0 } }
    private var scene: String { path == .hearing ? "HearingLake" : "WordMissionLandscape" }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let wide = size.width >= 800 && size.width > size.height && !typeSize.isAccessibilitySize
            ZStack {
                if path == .stories {
                    ReadLabMissionArt(name: "StoryQuizLandscape").ignoresSafeArea()
                    storyHome(wide: wide)
                } else if wide {
                    ReadLabMissionArt(name: scene).ignoresSafeArea()
                    voiceHome(size: size)
                } else {
                    ReadLabMissionArt(name: "StoryQuizLandscape").ignoresSafeArea()
                    compactVoiceHome
                }
            }
            .overlay(alignment: .topTrailing) {
                accountButton
                    .padding(.top, 16)
                    .padding(.trailing, wide ? 32 : 18)
            }
        }
        .foregroundStyle(ReadLabStyle.ink)
        .onChange(of: activeSession?.id) { _, id in audio?.setScene(id == nil ? .home : .practice) }
        .onChange(of: path) { _, _ in suggestionIndex = 0 }
        .sheet(isPresented: $settingsPresented) {
            ReadLabSettingsView(store: store).presentationSizing(.form)
        }
        .fullScreenCover(item: $activeSession) { session in
            ReadLabExerciseView(store: store, initialSession: session)
        }
    }

    private var accountButton: some View {
        Button { settingsPresented = true } label: {
            ReadLabMissionCircle(symbol: "person.crop.circle", size: 52)
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityLabel("Account")
        .accessibilityIdentifier("accountButton")
    }

    private func voiceHome(size: CGSize) -> some View {
        let panelCenter = size.width * 0.32
        let panelHeight = size.height * 0.43
        let panelY = size.height * 0.45
        let footerY = min(panelY + panelHeight / 2 + 62, size.height - 34)
        return ZStack {
            topicCard(fontSize: min(60, size.width * 0.050), buttonSize: 76,
                      panelSize: CGSize(width: size.width * 0.50, height: panelHeight))
                .position(x: panelCenter, y: panelY)
            mascot(embedded: path == .words)
                .frame(width: size.width * 0.20, height: size.height * 0.33)
                .position(x: size.width * 0.82, y: path == .words ? size.height * 0.43 : panelY)
            shuffle
                .frame(maxWidth: size.width * 0.44)
                .position(x: panelCenter, y: footerY)
            if let savedSession {
                resumeButton(savedSession)
                    .frame(maxWidth: size.width * 0.28)
                    .position(x: size.width * 0.82, y: footerY)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var compactVoiceHome: some View {
        ScrollView {
            VStack(spacing: 28) {
                ReadLabMissionArt(name: scene)
                    .aspectRatio(1366.0 / 1024.0, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 24))
                    .overlay(alignment: .trailing) {
                        mascot(embedded: path == .words).frame(width: 110, height: 150)
                    }
                topicCard(fontSize: 38, buttonSize: 74)
                shuffle
                if let savedSession { resumeButton(savedSession) }
            }
            .padding(.horizontal, 24)
            .padding(.top, 68)
            .padding(.bottom, 28)
        }
    }

    private func topicCard(fontSize: CGFloat, buttonSize: CGFloat, panelSize: CGSize? = nil) -> some View {
        Button { begin(suggestion) } label: {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Text("Suggested topic")
                        .readLabFont(min(25, fontSize * 0.54), weight: .medium)
                    Text(suggestion.title)
                        .readLabFont(fontSize, weight: .semibold)
                }
                .multilineTextAlignment(.center)
                ReadLabMissionCircle(symbol: "play.fill", size: buttonSize)
                    .accessibilityHidden(true)
            }
            .padding(panelSize == nil ? 42 : 20)
            .frame(maxWidth: .infinity)
            .frame(width: panelSize?.width, height: panelSize?.height)
            .modifier(ReadLabPracticeCloud(cornerRadius: panelSize == nil ? 24 : 28))
            .contentShape(.rect(cornerRadius: panelSize == nil ? 24 : 28))
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityLabel("Start \(suggestion.title)")
        .accessibilityIdentifier("startMissionButton")
    }

    private var shuffle: some View {
        Button { selectNext(1) } label: {
            homeActionLabel(path == .stories ? "Suggest another story" : "Suggest another topic", symbol: "shuffle")
                .fixedSize(horizontal: true, vertical: false)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { suggestedActionSize = $0 }
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityIdentifier("suggestAnotherTopicButton")
    }

    private func mascot(embedded: Bool) -> some View {
        Button { audio?.playAnimal(for: path) } label: {
            if embedded {
                Color.clear.contentShape(Rectangle())
            } else {
                Image(path.mascot).resizable().scaledToFit()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(path.mascot.lowercased()) sound")
        .accessibilityIdentifier("mascotButton")
    }

    private func storyHome(wide: Bool) -> some View {
        VStack(spacing: wide ? 20 : 16) {
            VStack(spacing: 8) {
                Text(suggestion.title)
                    .readLabFont(wide ? 46 : 32, weight: .semibold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("\(suggestionIndex + 1) of \(themes.count)")
                    .readLabFont(17, weight: .medium)
                    .accessibilityLabel("Story \(suggestionIndex + 1) of \(themes.count)")
            }
            .frame(maxWidth: .infinity)

            GeometryReader { available in
                let margin: CGFloat = wide ? 20 : 10
                let ratio: CGFloat = 1256.0 / 936.0
                let width = max(1, min(available.size.width - margin * 2,
                                       (available.size.height - margin * 2) * ratio))
                storyPreview(wide: wide, artworkSize: CGSize(width: width, height: width / ratio))
                    .id(suggestion.id)
                    .transition(.opacity)
                    .position(x: available.size.width / 2, y: available.size.height / 2)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { storyHomeActions }
                VStack(spacing: 12) { storyHomeActions }
            }
        }
        .frame(maxWidth: 1120)
        .padding(.horizontal, wide ? 80 : 16)
        .padding(.top, wide ? 64 : 72)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func storyPreview(wide: Bool, artworkSize: CGSize) -> some View {
        let inProgress = savedSession.flatMap { $0.themeID == suggestion.id ? $0 : nil }
        let age: ReadLabAgeRange? = if let inProgress { inProgress.storyAgeRange } else { store.data.profile.ageRange ?? .fourFive }
        let story = ReadLabLibrary.story(theme: suggestion.id, level: inProgress?.contentLevel ?? store.level(for: .stories), age: age)
        return Button { begin(suggestion) } label: {
            ReadLabStoryArtwork(name: suggestion.cover, viewport: artworkSize)
                .overlay(alignment: .top) {
                    Text(story.sections[0][0])
                        .readLabFont(wide ? 38 : 24, weight: .medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(typeSize.isAccessibilitySize ? 2 : nil)
                        .minimumScaleFactor(typeSize.isAccessibilitySize ? 0.65 : 1)
                        .padding(16)
                        .frame(maxWidth: .infinity,
                               maxHeight: typeSize.isAccessibilitySize ? artworkSize.height * 0.34 : nil,
                               alignment: .top)
                        .background(.ultraThinMaterial)
                }
                .overlay {
                    ReadLabMissionCircle(symbol: "play.fill", size: wide ? 86 : 64)
                        .accessibilityHidden(true)
                }
                .modifier(ReadLabBookPaper(margin: wide ? 20 : 10))
                .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityLabel("Start \(suggestion.title)")
        .accessibilityHint(story.sections[0][0])
        .accessibilityIdentifier("startMissionButton")
    }

    @ViewBuilder private var storyHomeActions: some View {
        shuffle
        if let savedSession { resumeButton(savedSession) }
    }

    private func resumeButton(_ session: PracticeSession) -> some View {
        Button { activeSession = session } label: {
            homeActionLabel("Resume \(ReadingTheme.find(session.themeID).title)", symbol: "arrow.clockwise", matchSuggest: true)
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityIdentifier("resumeSessionButton")
    }

    private func homeActionLabel(_ title: String, symbol: String, matchSuggest: Bool = false) -> some View {
        Label(title, systemImage: symbol)
            .readLabFont(21, weight: .semibold)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(width: matchSuggest && suggestedActionSize.width > 0 ? suggestedActionSize.width : nil,
                   height: matchSuggest && suggestedActionSize.height > 0 ? suggestedActionSize.height : nil)
            .frame(minHeight: 48)
            .background(.white, in: Capsule())
            .shadow(color: ReadLabStyle.ink.opacity(0.12), radius: 5, y: 2)
    }

    private func selectNext(_ direction: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            suggestionIndex = (suggestionIndex + direction + themes.count) % themes.count
        }
    }

    private func begin(_ theme: ReadingTheme) {
        if let savedSession, savedSession.themeID == theme.id { activeSession = savedSession }
        else { activeSession = store.start(path: path, theme: theme) }
    }
}
