import Foundation
import SwiftUI

/// A correct, ordered prefix only: skipping or substituting a word never advances the cursor.
struct ReadingAlignment {
    let wordCount: Int
    let matchedCount: Int
    let isComplete: Bool
    let containsMismatch: Bool

    init(transcript: String, target: String, startingAt offset: Int = 0) {
        let targetWords = SpeechMatch.normalized(target).split(separator: " ")
        let spokenWords = SpeechMatch.normalized(transcript).split(separator: " ")
        let remaining = Array(targetWords.dropFirst(max(0, offset)))
        let prefix = zip(spokenWords, remaining).prefix { $0 == $1 }.count
        containsMismatch = prefix < spokenWords.count
        wordCount = targetWords.count
        isComplete = !remaining.isEmpty && spokenWords == remaining
        // An extra word invalidates completion. Leave the last word available for a retry.
        let credited = prefix == remaining.count && spokenWords.count > remaining.count
            ? max(0, prefix - 1) : prefix
        matchedCount = min(wordCount, max(0, offset) + credited)
    }

    static func wordCount(in text: String) -> Int {
        SpeechMatch.normalized(text).split(separator: " ").count
    }

    static func highlighted(_ text: String, through count: Int) -> AttributedString {
        var result = AttributedString(text)
        guard count > 0,
              let regex = try? NSRegularExpression(pattern: #"[\p{L}\p{N}]+"#) else { return result }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty,
              let end = Range(matches[min(count, matches.count) - 1].range, in: text)?.upperBound,
              let attributedEnd = AttributedString.Index(end, within: result) else { return result }
        result[result.startIndex..<attributedEnd].backgroundColor = ReadLabStyle.sky
        result[result.startIndex..<attributedEnd].underlineStyle = .single
        return result
    }
}

struct StoryReadingProgress: Codable, Equatable {
    var paragraphIndex = 0
    var wordCount = 0
    var paragraphComplete = false
}

extension PracticeSession {
    /// New optional state keeps journeys saved before word tracking decodable.
    mutating func prepareStoryReading(in story: ReadingStory) {
        guard storyReading == nil else { return }
        sectionIndex = story.sectionIndex(forLegacySection: sectionIndex)
        storyReading = StoryReadingProgress()
    }

    @discardableResult
    mutating func updateStoryReading(transcript: String, startingAt offset: Int, in story: ReadingStory) -> ReadingAlignment? {
        guard path == .stories, !completed, !showingQuestions,
              var reading = storyReading, !reading.paragraphComplete,
              story.sections.indices.contains(sectionIndex),
              story.sections[sectionIndex].indices.contains(reading.paragraphIndex) else { return nil }
        let target = story.sections[sectionIndex][reading.paragraphIndex]
        let alignment = ReadingAlignment(transcript: transcript, target: target, startingAt: offset)
        reading.wordCount = alignment.matchedCount
        if alignment.isComplete {
            reading.paragraphComplete = true
            practiced += 1
        }
        storyReading = reading
        return alignment
    }

    mutating func advanceStoryParagraph(in story: ReadingStory) {
        guard storyReading?.paragraphComplete == true, !showingQuestions, !completed,
              story.sections.indices.contains(sectionIndex) else { return }
        let paragraph = storyReading?.paragraphIndex ?? 0
        if paragraph + 1 < story.sections[sectionIndex].count {
            storyReading = StoryReadingProgress(paragraphIndex: paragraph + 1)
        } else if sectionIndex + 1 < story.sections.count {
            sectionIndex += 1
            storyReading = StoryReadingProgress()
        } else {
            showingQuestions = true
            answeredCurrentItem = false
            storyReading = StoryReadingProgress()
        }
    }
}
