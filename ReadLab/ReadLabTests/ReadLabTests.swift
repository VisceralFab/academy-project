import Foundation
import AVFoundation
import Testing
import UIKit
import SwiftUI
@testable import ReadLab

@MainActor
struct ReadLabTests {
    @Test func childProfileOnlyRequiresAName() {
        var profile = ReadLabChildProfile()
        #expect(!profile.isValid)
        profile.childName = "   "
        #expect(!profile.isValid)
        profile.childName = "Luca"
        #expect(profile.isValid)
        #expect(profile.readingFamiliarity == nil)
    }

    @Test func syllableLensMovesContinuouslyBetweenNeighbours() {
        let widths: [CGFloat] = [80, 80, 80, 80]
        let left = SyllableLens.scales(widths: widths, position: 0.499)
        let right = SyllableLens.scales(widths: widths, position: 0.501)
        #expect(abs(left[1] - right[1]) < 0.01)
        #expect(abs(left[2] - right[2]) < 0.01)
        #expect(left[1] > 1.1 && left[2] > 1.1)
        #expect(SyllableLens.scales(widths: [], position: 0.5).isEmpty)
    }

    @Test func syllableLensAccountsForActualGlyphWidths() {
        let widths: [CGFloat] = [40, 160, 65]
        let middle = SyllableLens.position(of: 1, widths: widths)
        let scales = SyllableLens.scales(widths: widths, position: middle)
        #expect(abs(scales[1] - 1.42) < 0.001)
        #expect(scales[1] > scales[0] && scales[1] > scales[2])
        #expect(SyllableLens.position(of: 0, widths: widths) == 0)
        #expect(SyllableLens.position(of: 2, widths: widths) == 1)
    }

    @Test func difficultyAdaptsWithoutLeavingBounds() {
        var difficulty = AdaptiveDifficulty()
        let firstChange = difficulty.record(success: true)
        #expect(!firstChange)
        let secondChange = difficulty.record(success: true)
        #expect(!secondChange)
        let promotion = difficulty.record(success: true)
        #expect(promotion)
        #expect(difficulty.level == 2)
        let firstMistake = difficulty.record(success: false)
        #expect(!firstMistake)
        let simplification = difficulty.record(success: false)
        #expect(simplification)
        #expect(difficulty.level == 1)
        for _ in 0..<40 { difficulty.record(success: true) }
        #expect(difficulty.level == 5)
        for _ in 0..<40 { difficulty.record(success: false) }
        #expect(difficulty.level == 1)
    }

    @Test func aMistakeBreaksTheSuccessStreak() {
        var difficulty = AdaptiveDifficulty()
        difficulty.record(success: true)
        difficulty.record(success: true)
        difficulty.record(success: false)
        difficulty.record(success: true)
        #expect(difficulty.level == 1)
        #expect(difficulty.successStreak == 1)
        #expect(difficulty.mistakes == 0)
    }

    @Test func speechRequiresTheWholePrompt() {
        #expect(SpeechMatch.matches("THE moon shines at night!", target: "The moon shines at night."))
        #expect(SpeechMatch.matches("  Rabbit. ", target: "rabbit"))
        #expect(!SpeechMatch.matches("cat", target: "caterpillar"))
        #expect(!SpeechMatch.matches("the moon", target: "The moon shines at night."))
        #expect(!SpeechMatch.matches("the moon shines at night extra", target: "The moon shines at night."))
        #expect(!SpeechMatch.matches("", target: ""))
    }

    @Test func everyPathResumesItsOwnSessionAfterRelaunch() throws {
        let suite = "readlab.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadLabStore(defaults: defaults)
        store.data.hasOnboarded = true
        store.data.profile.childName = "Luca"
        store.data.preferences.useDyslexicFont = true
        store.data.selectedPath = .words
        for path in ReadingPath.allCases {
            var session = store.start(path: path, theme: ReadingTheme.themes(for: path)[0])
            session.itemIndex = 3
            session.sectionIndex = 1
            session.questionIndex = 2
            session.showingQuestions = true
            session.answeredCurrentItem = true
            store.update(session)
            store.record(success: true, path: path)
        }
        let restored = ReadLabStore(defaults: defaults)
        #expect(restored.data == store.data)
        #expect(restored.data.preferences.useDyslexicFont)
        #expect(restored.session(for: .stories)?.questionIndex == 2)
        #expect(restored.session(for: .words)?.answeredCurrentItem == true)
    }

    @Test func trackingOptOutClearsAnalyticsButKeepsResumeAndAdaptation() throws {
        let suite = "readlab.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadLabStore(defaults: defaults)
        let session = store.start(path: .words, theme: ReadingTheme.themes(for: .words)[0])
        store.record(success: true, path: .words)
        #expect(store.data.totals["words"]?.attempts == 1)
        store.setTracking(false)
        for _ in 0..<3 { store.record(success: true, path: .words) }
        #expect(store.data.totals.isEmpty)
        #expect(store.session(for: .words)?.id == session.id)
        #expect(store.level(for: .words) == 2)
    }

    @Test func exerciseLogFeedsPerformanceReport() throws {
        let suite = "readlab.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadLabStore(defaults: defaults)
        store.data.profile.childName = "Ada"
        var session = store.start(path: .words, theme: ReadingTheme.themes(for: .words)[0])
        store.record(success: true, path: .words, themeID: session.themeID, item: "cat")
        store.record(success: false, path: .words, themeID: session.themeID, item: "dog")
        store.recordAssisted(path: .words, themeID: session.themeID, item: "bird")
        store.finish(&session)
        #expect(store.data.exerciseLog.map(\.outcome) == [.correct, .retry, .assisted, .completed])

        let url = try ReadLabPerformanceReport.makePDF(from: store.data)
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try Data(contentsOf: url)
        #expect(pdf.starts(with: Data("%PDF".utf8)))

        store.setTracking(false)
        #expect(store.data.exerciseLog.isEmpty)
    }

    @Test func completionIsCountedOnce() throws {
        let suite = "readlab.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadLabStore(defaults: defaults)
        var session = store.start(path: .hearing, theme: ReadingTheme.themes(for: .hearing)[0])
        store.finish(&session)
        store.finish(&session)
        #expect(store.data.totals["hearing"]?.completedActivities == 1)
        #expect(store.session(for: .hearing)?.completed == true)
    }

    @Test func wordPracticeHasTwoToSixSyllables() {
        for theme in ReadingTheme.themes(for: .words) {
            for level in 1...5 {
                let prompts = ReadLabLibrary.prompts(theme: theme.id, level: level)
                #expect(prompts.count == 6)
                for prompt in prompts {
                    let pieces = prompt.syllables.flatMap { $0.components(separatedBy: .whitespaces) }.filter { !$0.isEmpty }
                    #expect(pieces.count == level + 1, "\(theme.id), level \(level): \(prompt.text)")
                    #expect(SpeechMatch.normalized(pieces.joined()) == SpeechMatch.normalized(prompt.text.replacingOccurrences(of: " ", with: "")))
                }
            }
        }
    }

    @Test func storiesHaveShortSectionsAndValidQuestions() {
        for theme in ReadingTheme.themes(for: .stories) {
            var previousWordCount = 0
            for level in 1...5 {
                let story = ReadLabLibrary.story(theme: theme.id, level: level)
                #expect(story.sections.allSatisfy { !$0.isEmpty && $0.count <= 2 })
                #expect(story.questions.count >= 3)
                #expect(story.questions.allSatisfy { $0.options.indices.contains($0.answer) })
                let words = story.sections.flatMap { $0 }.joined(separator: " ").split(separator: " ").count
                #expect(words > previousWordCount)
                previousWordCount = words
            }
        }
    }

    @Test func readingAlignsOnlyCorrectOrderedWords() {
        let target = "The little monkey walks west."
        let partial = ReadingAlignment(transcript: "THE little", target: target)
        #expect(partial.matchedCount == 2 && !partial.isComplete && !partial.containsMismatch)
        let skipped = ReadingAlignment(transcript: "The monkey walks west", target: target)
        #expect(skipped.matchedCount == 1 && !skipped.isComplete && skipped.containsMismatch)
        let wrong = ReadingAlignment(transcript: "The little donkey walks west", target: target)
        #expect(wrong.matchedCount == 2 && !wrong.isComplete)
        #expect(ReadingAlignment(transcript: "monkey walks west!", target: target, startingAt: 2).isComplete)
        #expect(!ReadingAlignment(transcript: "monkey walks east", target: target, startingAt: 2).isComplete)
        #expect(!ReadingAlignment(transcript: "The little monkey walks west extra", target: target).isComplete)
        #expect(!ReadingAlignment(transcript: "", target: target).isComplete)
        #expect(!ReadingAlignment(transcript: "west", target: "west west").isComplete)
        #expect(ReadingAlignment(transcript: "fox's red gate!", target: "Fox’s red gate.").isComplete)
    }

    @Test func storyTracksRevisionsAndAdvancesOnlyCompletedParagraphs() {
        let story = ReadingStory(title: "A walk", sections: [["The monkey walks.", "He sees a gate.", "He waves."]], questions: [])
        #expect(story.sections.map(\.count) == [2, 1])
        var session = PracticeSession(path: .stories, themeID: "journey")
        session.prepareStoryReading(in: story)
        session.advanceStoryParagraph(in: story)
        #expect(session.storyReading?.paragraphIndex == 0 && !session.showingQuestions)
        session.updateStoryReading(transcript: "The monkey", startingAt: 0, in: story)
        #expect(session.storyReading?.wordCount == 2)
        session.updateStoryReading(transcript: "The donkey", startingAt: 0, in: story)
        #expect(session.storyReading?.wordCount == 1) // A revised partial result retracts an uncertain word.
        session.updateStoryReading(transcript: "monkey walks", startingAt: 1, in: story)
        #expect(session.storyReading?.paragraphComplete == true)
        #expect(session.updateStoryReading(transcript: "monkey walks", startingAt: 1, in: story) == nil)
        #expect(session.practiced == 1)
        session.advanceStoryParagraph(in: story)
        #expect(session.storyReading == StoryReadingProgress(paragraphIndex: 1))
        #expect(session.sectionIndex == 0 && !session.showingQuestions)
        session.updateStoryReading(transcript: "he sees a gate", startingAt: 0, in: story)
        session.advanceStoryParagraph(in: story)
        #expect(session.sectionIndex == 1 && session.storyReading?.paragraphIndex == 0)
        session.updateStoryReading(transcript: "he waves", startingAt: 0, in: story)
        session.advanceStoryParagraph(in: story)
        #expect(session.showingQuestions && !session.answeredCurrentItem)
        #expect(session.practiced == 3)
    }

    @Test func storyProgressSurvivesSaveAndLegacySessionsStillDecode() throws {
        var session = PracticeSession(path: .stories, themeID: "journey")
        session.storyReading = StoryReadingProgress(paragraphIndex: 1, wordCount: 7)
        let restored = try JSONDecoder().decode(PracticeSession.self, from: JSONEncoder().encode(session))
        #expect(restored == session)
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        legacy.removeValue(forKey: "storyReading")
        legacy["sectionIndex"] = 1
        var migrated = try JSONDecoder().decode(PracticeSession.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(migrated.storyReading == nil)
        let story = ReadingStory(title: "Legacy", sections: [["a", "b", "c"], ["d", "e"]], questions: [])
        migrated.prepareStoryReading(in: story)
        #expect(migrated.sectionIndex == 2)
        #expect(migrated.storyReading == StoryReadingProgress())
    }

    @Test func wordHighlightPreservesOriginalTypographyAndPunctuation() {
        let original = "“Fox’s” red gate."
        let highlighted = ReadingAlignment.highlighted(original, through: 2)
        #expect(String(highlighted.characters) == original)
        #expect(highlighted.runs.first?.backgroundColor == ReadLabStyle.sky)
        #expect(highlighted.runs.last?.backgroundColor == nil)
        #expect(ReadingAlignment.highlighted(original, through: 0).runs.first?.backgroundColor == nil)
    }

    @Test func allEightAudioFilesDecodeAndAnimalMappingIsCorrect() throws {
        for sound in ReadLabSound.allCases {
            let url = try #require(sound.url, "Missing bundled audio: \(sound.rawValue)")
            let player = try AVAudioPlayer(contentsOf: url)
            #expect(player.duration > 0)
            #expect(player.numberOfChannels > 0)
        }
        #expect(ReadLabSound.animal(for: .hearing, mascot: false) == .elephantCard)
        #expect(ReadLabSound.animal(for: .hearing, mascot: true) == .elephantMascot)
        #expect(ReadLabSound.animal(for: .words, mascot: false) == .parrotCard)
        #expect(ReadLabSound.animal(for: .words, mascot: true) == .parrotMascot)
        #expect(ReadLabSound.animal(for: .stories, mascot: false) == .monkeyCard)
        #expect(ReadLabSound.animal(for: .stories, mascot: true) == .monkeyMascot)
    }

    @Test func musicFollowsSceneMuteAndInterruptionAndRemembersPreferences() throws {
        let suite = "readlab.audio-tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let audio = ReadLabAudioController(defaults: defaults)
        defer { audio.setActive(false) }
        #expect(audio.requestedMusic == nil)
        audio.setActive(true)
        #expect(audio.requestedMusic == .onboarding)
        audio.setScene(.home)
        #expect(audio.requestedMusic == .home)
        audio.setScene(.practice)
        #expect(audio.requestedMusic == nil)
        audio.setScene(.home)
        audio.setInterrupted(true)
        #expect(audio.requestedMusic == nil)
        audio.setInterrupted(false)
        #expect(audio.requestedMusic == .home)
        audio.handleRouteChange(Notification(name: AVAudioSession.routeChangeNotification, userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]))
        #expect(audio.requestedMusic == nil)
        audio.toggleMusic()
        #expect(audio.requestedMusic == .home)
        audio.musicEnabled = false
        audio.effectsEnabled = false
        #expect(audio.requestedMusic == nil)
        let restored = ReadLabAudioController(defaults: defaults)
        #expect(!restored.musicEnabled && !restored.effectsEnabled)
    }

    @Test func onboardingMusicFadesBeforeHomeAndStopsForPractice() async throws {
        let suite = "readlab.music-transition-tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let audio = ReadLabAudioController(defaults: defaults)
        defer { audio.setActive(false) }
        audio.setActive(true)
        try await Task.sleep(for: .seconds(0.2))
        #expect(audio.playingMusic == .onboarding && audio.isMusicPlaying)
        audio.setScene(.home)
        try await Task.sleep(for: .seconds(0.2))
        #expect(audio.playingMusic == .onboarding) // The outgoing fade must finish first.
        try await Task.sleep(for: .seconds(1.2))
        #expect(audio.playingMusic == .home && audio.isMusicPlaying)
        audio.setScene(.practice)
        #expect(!audio.isMusicPlaying)
        audio.setScene(.onboarding)
        audio.setActive(false) // Cancels a pending transition; it must not restart in the background.
        try await Task.sleep(for: .seconds(1.4))
        #expect(!audio.isMusicPlaying)
    }

    @Test func bundledFontIsRegistered() {
        #expect(Bundle.main.url(forResource: "OpenDyslexic-Bold", withExtension: "otf") != nil)
        #expect(UIFont(name: "OpenDyslexic-Bold", size: 20) != nil)
    }
}
