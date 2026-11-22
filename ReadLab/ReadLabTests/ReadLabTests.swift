import Foundation
import AVFoundation
import Testing
import UIKit
import SwiftUI
@testable import ReadLab

@MainActor
struct ReadLabTests {
    @Test func childProfileRequiresNameAndAge() {
        var profile = ReadLabChildProfile()
        #expect(!profile.isValid)
        profile.childName = "   "
        #expect(!profile.isValid)
        profile.childName = "Luca"
        #expect(!profile.isValid)
        profile.ageRange = .sixSeven
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
                    #expect((2...6).contains(pieces.count), "\(theme.id), level \(level): \(prompt.text)")
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

    @Test func illustratedStoryEditionsMatchAgeAndKeepNinePages() throws {
        let profiles: [(ReadLabAgeRange, ClosedRange<Int>, Int)] = [
            (.fourFive, 3...8, 1), (.sixSeven, 8...18, 2), (.eightNine, 15...30, 2), (.tenPlus, 20...45, 3)
        ]
        for theme in ReadingTheme.themes(for: .stories) {
            var previousWords = 0
            for (age, bounds, sentenceLimit) in profiles {
                let story = ReadLabLibrary.story(theme: theme.id, level: 1, age: age)
                let pages = story.sections.flatMap { $0 }
                #expect(pages.count == 9)
                #expect(story.sections.allSatisfy { (1...2).contains($0.count) })
                #expect(story.questions.count == 6)
                #expect(story.questions.allSatisfy { $0.options.indices.contains($0.answer) && Set($0.options).count == 3 })
                for (index, page) in pages.enumerated() {
                    #expect(bounds.contains(page.split(whereSeparator: \.isWhitespace).count), "\(theme.title), \(age.rawValue), page \(index + 1)")
                    #expect(page.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count <= sentenceLimit)
                    let asset = ReadLabIllustratedStories.artwork(for: theme, page: index + 1)
                    #expect(UIImage(named: asset) != nil)
                }
                let total = pages.flatMap { $0.split(whereSeparator: \.isWhitespace) }.count
                #expect(total > previousWords)
                previousWords = total
                #expect(story == ReadLabLibrary.story(theme: theme.id, level: 5, age: age))
            }
        }
    }

    @Test func illustratedStoryAgeIsFrozenForNewSessionsAndOptionalForOldOnes() throws {
        let suite = "readlab.age-story.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadLabStore(defaults: defaults)
        let theme = try #require(ReadingTheme.themes(for: .stories).first)
        #expect(store.start(path: .stories, theme: theme).storyAgeRange == .fourFive)
        store.data.profile.ageRange = .eightNine
        var session = store.start(path: .stories, theme: theme)
        session.storyReading = StoryReadingProgress(paragraphIndex: 1, wordCount: 3)
        store.update(session)
        store.data.profile.ageRange = .tenPlus

        let reopened = ReadLabStore(defaults: defaults)
        #expect(reopened.session(for: .stories)?.storyAgeRange == .eightNine)
        #expect(reopened.session(for: .stories)?.storyReading?.wordCount == 3)
        let legacy = PracticeSession(path: .stories, themeID: theme.id, contentLevel: 3)
        let decoded = try JSONDecoder().decode(PracticeSession.self, from: JSONEncoder().encode(legacy))
        #expect(decoded.storyAgeRange == nil)
        #expect(ReadLabLibrary.story(theme: theme.id, level: decoded.contentLevel, age: decoded.storyAgeRange)
                == ReadLabIllustratedStories.story(theme: theme.id, level: 3))
    }

    @Test func storyKeepsEveryRecognizedWordAcrossRevisionsAndPauses() {
        let story = ReadingStory(title: "A walk", sections: [["He sees a river. His friend helps him cross.", "He sees a gate.", "He waves."]], questions: [])
        var session = PracticeSession(path: .stories, themeID: "journey")
        var cursor = StorySpeechCursor()
        session.prepareStoryReading(in: story)
        session.advanceStoryParagraph(in: story)
        #expect(session.storyReading?.paragraphIndex == 0)

        for (transcript, expected) in [
            ("He", 1), ("He sees a river", 4), ("He sees", 4), ("He sees a river", 4),
            ("She sees a river", 4), ("She sees a river, friend helps", 4),
            ("She sees a river, friend helps, um, his friend", 6),
            ("She sees a river, friend helps, um, his friend helps", 7)
        ] {
            #expect(!session.updateStoryReading(transcript: transcript, cursor: &cursor, in: story))
            #expect(session.storyReading?.wordCount == expected)
        }

        // A new recognition request starts after a pause and uses the saved position.
        cursor = StorySpeechCursor()
        #expect(!session.updateStoryReading(transcript: "him", cursor: &cursor, in: story))
        #expect(session.storyReading?.wordCount == 8)
        #expect(session.updateStoryReading(transcript: "him cross, okay", cursor: &cursor, in: story))
        #expect(!session.updateStoryReading(transcript: "him cross, okay", cursor: &cursor, in: story))
        #expect(session.practiced == 1)
        session.advanceStoryParagraph(in: story)
        #expect(session.storyReading == StoryReadingProgress(paragraphIndex: 1))
        #expect(session.sectionIndex == 0 && !session.showingQuestions)

        cursor = StorySpeechCursor()
        #expect(session.updateStoryReading(transcript: "he sees a gate", cursor: &cursor, in: story))
        session.advanceStoryParagraph(in: story)
        #expect(session.sectionIndex == 1 && session.storyReading?.paragraphIndex == 0)
        cursor = StorySpeechCursor()
        #expect(session.updateStoryReading(transcript: "he waves", cursor: &cursor, in: story))
        session.advanceStoryParagraph(in: story)
        #expect(session.showingQuestions && !session.answeredCurrentItem)
        #expect(session.practiced == 3)
    }

    @Test func storyContinuesIntoSecondParagraphInTheSameTranscript() {
        let story = ReadLabLibrary.story(theme: "journey", level: 1)
        let first = story.sections[0][0]
        let second = story.sections[0][1]
        var session = PracticeSession(path: .stories, themeID: "journey")
        var cursor = StorySpeechCursor()
        session.prepareStoryReading(in: story)

        #expect(session.readStoryTranscript(first + " He sees", cursor: &cursor, in: story) == [first])
        #expect(session.storyReading?.paragraphIndex == 1)
        #expect(session.storyReading?.wordCount == 2)
        #expect(session.readStoryTranscript(first + " He sees", cursor: &cursor, in: story).isEmpty)
        #expect(session.storyReading?.wordCount == 2)
        #expect(session.readStoryTranscript(first + " He sees red bag", cursor: &cursor, in: story).isEmpty)
        #expect(session.storyReading?.wordCount == 2)
        #expect(session.readStoryTranscript(first + " " + second, cursor: &cursor, in: story) == [second])
        #expect(session.showingQuestions)
        #expect(session.practiced == 2)
    }

    @Test func storyResumesSecondParagraphAfterTheRecognizerStartsANewSegment() {
        let story = ReadingStory(title: "Two sentences", sections: [["Go west.", "Go east."]], questions: [])
        var session = PracticeSession(path: .stories, themeID: "journey")
        var cursor = StorySpeechCursor()
        session.prepareStoryReading(in: story)

        #expect(session.readStoryTranscript("Go west", cursor: &cursor, in: story) == ["Go west."])
        #expect(session.storyReading == StoryReadingProgress(paragraphIndex: 1))
        #expect(session.readStoryTranscript("Go west", cursor: &cursor, in: story).isEmpty)
        #expect(session.storyReading?.wordCount == 0)

        cursor = StorySpeechCursor()
        #expect(session.readStoryTranscript("Red bag", cursor: &cursor, in: story).isEmpty)
        #expect(session.storyReading?.wordCount == 0)
        #expect(session.readStoryTranscript("Red bag, go", cursor: &cursor, in: story).isEmpty)
        #expect(session.storyReading?.wordCount == 1)
        #expect(session.readStoryTranscript("Red bag, go east", cursor: &cursor, in: story) == ["Go east."])
        #expect(session.showingQuestions)
    }

    @Test func storyAcceptsAReplacementFragmentAtTheSecondParagraph() {
        let story = ReadingStory(title: "A walk", sections: [["The fox sees a gate.", "A bird is lost."]], questions: [])
        var session = PracticeSession(path: .stories, themeID: "torii")
        var cursor = StorySpeechCursor()
        session.prepareStoryReading(in: story)

        #expect(session.readStoryTranscript("The fox sees a gate", cursor: &cursor, in: story) == ["The fox sees a gate."])
        #expect(session.readStoryTranscript("A bird", cursor: &cursor, in: story).isEmpty)
        #expect(session.storyReading?.wordCount == 2)
        #expect(session.readStoryTranscript("A bird is lost", cursor: &cursor, in: story) == ["A bird is lost."])
        #expect(session.showingQuestions)
    }

    @Test func storyAcceptsKnownSoundAlikesOnlyForTheNextWord() {
        let story = ReadingStory(title: "A walk", sections: [["The western hills."]], questions: [])
        var session = PracticeSession(path: .stories, themeID: "journey")
        var cursor = StorySpeechCursor()
        session.prepareStoryReading(in: story)

        #expect(session.readStoryTranscript("The heels", cursor: &cursor, in: story).isEmpty)
        #expect(session.storyReading?.wordCount == 1)
        #expect(session.readStoryTranscript("The western wheels", cursor: &cursor, in: story).isEmpty)
        #expect(session.storyReading?.wordCount == 2)
        #expect(session.readStoryTranscript("Heels", cursor: &cursor, in: story) == ["The western hills."])
        #expect(session.showingQuestions)

        #expect(!SpeechMatch.matches("heels", target: "hills"))
    }

    @Test func phoneticMatcherUsesBundledCMUdictAndAllPronunciations() throws {
        let license = Bundle.main.url(forResource: "CMUdict-LICENSE", withExtension: "txt")
            ?? Bundle.main.url(forResource: "CMUdict-LICENSE", withExtension: "txt", subdirectory: "Pronunciation")
        let licenseURL = try #require(license)
        #expect(try String(contentsOf: licenseURL, encoding: .utf8).contains("Carnegie Mellon University"))
        let matcher = PhoneticMatcher(configuration: .init(allowedVowelPairs: []))
        #expect(matcher.matches("sea", expected: "see"))
        #expect(matcher.matches("too", expected: "two"))
        #expect(matcher.matches("red", expected: "read"))
        #expect(matcher.matches("reed", expected: "read"))
        #expect(!matcher.matches("heels", expected: "hills"))
    }

    @Test func phoneticMatcherLimitsNearMatchesAndHandlesUnknownWords() {
        let matcher = PhoneticMatcher()
        #expect(matcher.matches("heels", expected: "hills"))
        #expect(!matcher.matches("wheels", expected: "hills"))
        #expect(!matcher.matches("bed", expected: "bad"))
        #expect(!matcher.matches("cool", expected: "could"))
        #expect(!matcher.matches("call", expected: "could"))
        #expect(matcher.matches("zzreadlabxx", expected: "zzreadlabxx"))
        #expect(!matcher.matches("zzreadlabyy", expected: "zzreadlabxx"))
        let custom = PhoneticMatcher(configuration: .init(allowedVowelPairs: [.init("AE", "EH")]))
        #expect(custom.matches("bed", expected: "bad"))
        #expect(!custom.matches("heels", expected: "hills"))
    }

    @Test func storyDoesNotCreditRevisedSoundAlikesTwice() {
        var cursor = StorySpeechCursor()
        let target = StoryText.words(in: "See sea hills heels.")
        #expect(cursor.advance(transcript: "See", target: target, from: 0) == 1)
        #expect(cursor.advance(transcript: "Sea", target: target, from: 1) == 1)
        #expect(cursor.advance(transcript: "Sea sea heels", target: target, from: 1) == 3)
        #expect(cursor.advance(transcript: "See sea hills", target: target, from: 3) == 3)
        #expect(cursor.advance(transcript: "See sea", target: target, from: 3) == 3)
        #expect(cursor.advance(transcript: "See sea hills heels", target: target, from: 3) == 4)
    }

    @Test func storyUsesSpeechAlternativesAtTheMatchingWordPosition() {
        let text = "She head the bird."
        let target = StoryText.words(in: "She heard the bird.")
        let range = (text as NSString).range(of: "head")
        for alternatives in [
            SpeechWordAlternatives(text: text, segments: [.init(range: range, alternatives: ["heard"])]),
            SpeechWordAlternatives(text: text, transcripts: ["She heard the bird."])
        ] {
            var cursor = StorySpeechCursor()
            #expect(cursor.advance(transcript: text, target: target, from: 0, alternatives: alternatives) == 4)
        }
        var cursor = StorySpeechCursor()
        let misaligned = SpeechWordAlternatives(text: text, transcripts: ["She heard the fox.", "She heard the little bird."])
        #expect(cursor.advance(transcript: text, target: target, from: 0, alternatives: misaligned) == 1)
    }

    @Test func storyCursorDoesNotSkipWordsOrCountDuplicateCallbacks() {
        var cursor = StorySpeechCursor()
        let target = StoryText.words(in: "Go go go back to Fox’s gate.")
        #expect(cursor.advance(transcript: "Go", target: target, from: 0) == 1)
        #expect(cursor.advance(transcript: "Go", target: target, from: 1) == 1)
        #expect(cursor.advance(transcript: "Go go", target: target, from: 1) == 2)
        #expect(cursor.advance(transcript: "Go", target: target, from: 2) == 2)
        #expect(cursor.advance(transcript: "Go go back", target: target, from: 2) == 2)
        #expect(cursor.advance(transcript: "Go go go back", target: target, from: 2) == 4)
        #expect(cursor.advance(transcript: "Go go go back to fox's gate!", target: target, from: 4) == target.count)
    }

    @Test func storyCursorAcceptsNewFragmentsAndCorrections() {
        var cursor = StorySpeechCursor()
        let target = StoryText.words(in: "A bird is lost. Tori helps it.")
        #expect(cursor.advance(transcript: "A bird is lost", target: target, from: 0) == 4)
        #expect(cursor.advance(transcript: "Tony helps", target: target, from: 4) == 4)
        #expect(cursor.advance(transcript: "Tory helps", target: target, from: 4) == 6)
        #expect(cursor.advance(transcript: "Tori helps it", target: target, from: 6) == 7)
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
        let highlighted = StoryText.highlighted(original, through: 2)
        #expect(String(highlighted.characters) == original)
        #expect(highlighted.runs.first?.backgroundColor == ReadLabStyle.sky)
        #expect(highlighted.runs.last?.backgroundColor == nil)
        #expect(StoryText.highlighted(original, through: 0).runs.first?.backgroundColor == nil)
    }

    @Test func bundledAudioFilesDecodeAndUseOnlySecondAnimalVariants() throws {
        for sound in ReadLabSound.allCases {
            let url = try #require(sound.url, "Missing bundled audio: \(sound.rawValue)")
            let player = try AVAudioPlayer(contentsOf: url)
            #expect(player.duration > 0)
            #expect(player.numberOfChannels > 0)
        }
        #expect(ReadLabSound.animal(for: .hearing) == .elephantMascot)
        #expect(ReadLabSound.animal(for: .words) == .parrotMascot)
        #expect(ReadLabSound.animal(for: .stories) == .monkeyMascot)
        for obsolete in ["Elephant 1", "Monkey 1", "Parrot 1", "Home music"] {
            #expect(Bundle.main.url(forResource: obsolete, withExtension: "mp3") == nil)
        }
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
