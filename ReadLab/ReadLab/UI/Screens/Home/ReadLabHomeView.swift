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
    private var themes: [ReadingTheme] {
        let list = ReadingTheme.themes(for: path)
        return path == .words ? Array(list.reversed()) : list
    }
    private var suggestion: ReadingTheme { themes[suggestionIndex % themes.count] }
    private var suggestedSession: PracticeSession { store.plannedSession(for: suggestion) }
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
        .onChange(of: path, initial: true) { _, current in
            let lastTheme = store.session(for: current)?.themeID
            suggestionIndex = themes.firstIndex { $0.id == lastTheme } ?? 0
        }
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
                .position(x: panelCenter, y: footerY)
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 68)
            .padding(.bottom, 28)
        }
    }

    private func topicCard(fontSize: CGFloat, buttonSize: CGFloat, panelSize: CGSize? = nil) -> some View {
        let session = suggestedSession
        let total = ReadLabLibrary.prompts(theme: session.themeID, level: session.contentLevel).count
        let count = session.completed ? total : min(total, session.itemIndex + (session.answeredCurrentItem ? 1 : 0))
        let countLabel = "\(count) of \(total) words"
        let level = session.completed ? "Level \(session.wordLevel.title) complete" : "Level \(session.wordLevel.title)"
        let previousCompletion = store.data.activities[session.themeID]?.lastCompleted(before: session.wordLevel)
            .map { "\($0.title) complete" }
        let progressDescription = [level, countLabel, previousCompletion].compactMap { $0 }.joined(separator: ", ")
        let shortPanel = panelSize.map { $0.height < 330 } ?? false

        return Button { begin(suggestion) } label: {
            VStack(spacing: 0) {
                if panelSize != nil { Spacer(minLength: 0) }
                VStack(spacing: shortPanel ? 14 : 22) {
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
                if panelSize != nil { Spacer(minLength: 14) }
                VStack(spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Text(level).fixedSize()
                            Spacer(minLength: 0)
                            Text(countLabel).fixedSize()
                        }
                        VStack(spacing: 4) {
                            Text(level)
                            Text(countLabel)
                        }
                    }
                    .readLabFont(17, weight: .medium)
                    linearProgress(count, total: total)
                    if let previousCompletion {
                        Label(previousCompletion, systemImage: "checkmark.circle.fill")
                            .readLabFont(15, weight: .medium)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .padding(.top, panelSize == nil ? 26 : 0)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, panelSize == nil ? 32 : 28)
            .padding(.vertical, panelSize == nil ? 36 : (shortPanel ? 16 : 24))
            .frame(maxWidth: .infinity)
            .frame(width: panelSize?.width, height: panelSize?.height)
            .modifier(ReadLabPracticeCloud(cornerRadius: panelSize == nil ? 24 : 28))
            .contentShape(.rect(cornerRadius: panelSize == nil ? 24 : 28))
        }
        .buttonStyle(ReadLabTapStyle())
        .accessibilityLabel("Start \(suggestion.title)")
        .accessibilityValue(progressDescription)
        .accessibilityIdentifier("startMissionButton")
    }

    private var shuffle: some View {
        Button { selectNext(1) } label: {
            homeActionLabel(path == .stories ? "Suggest another story" : "Suggest another topic", symbol: "shuffle")
                .fixedSize(horizontal: true, vertical: false)
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
        var session = suggestedSession
        let story = ReadLabLibrary.story(theme: session.themeID, level: session.contentLevel, age: session.storyAgeRange)
        session.prepareStoryReading(in: story)
        let total = story.sections.reduce(0) { $0 + $1.count }
        let count = session.completed || session.showingQuestions ? total : min(total, session.pagesRead(in: story))

        return VStack(spacing: wide ? 20 : 16) {
            VStack(spacing: 10) {
                Text(suggestion.title)
                    .readLabFont(wide ? 46 : 32, weight: .semibold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 7) {
                    Text("\(count) of \(total) pages")
                        .readLabFont(17, weight: .medium)
                        .accessibilityIdentifier("homeProgressCount")
                    linearProgress(count, total: total)
                }
                .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity)

            GeometryReader { available in
                let margin: CGFloat = wide ? 20 : 10
                let ratio: CGFloat = 1256.0 / 936.0
                let width = max(1, min(available.size.width - margin * 2,
                                       (available.size.height - margin * 2) * ratio))
                storyPreview(story, wide: wide, artworkSize: CGSize(width: width, height: width / ratio))
                    .id(suggestion.id)
                    .transition(.opacity)
                    .position(x: available.size.width / 2, y: available.size.height / 2)
            }
            shuffle
        }
        .frame(maxWidth: 1120)
        .padding(.horizontal, wide ? 80 : 16)
        .padding(.top, wide ? 64 : 72)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func storyPreview(_ story: ReadingStory, wide: Bool, artworkSize: CGSize) -> some View {
        Button { begin(suggestion) } label: {
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

    private func linearProgress(_ count: Int, total: Int) -> some View {
        ProgressView(value: Double(count), total: Double(max(1, total)))
            .progressViewStyle(.linear)
            .tint(ReadLabStyle.ink)
            .accessibilityHidden(true)
    }

    private func homeActionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .readLabFont(21, weight: .semibold)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
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
        activeSession = store.open(theme)
    }
}
