import Foundation
import SwiftUI

/// Uses the same word boundaries for recognition, the counter, and highlighting.
enum StoryText {
    private static let wordPattern = #/[\p{L}\p{M}\p{N}]+/#

    static func words(in text: String) -> [Substring] {
        SpeechMatch.normalized(text).split(separator: " ")
    }

    static func wordCount(in text: String) -> Int {
        words(in: text).count
    }

    static func highlighted(_ text: String, through count: Int) -> AttributedString {
        var result = AttributedString(text)
        guard count > 0 else { return result }
        let matches = text.matches(of: wordPattern)
        guard !matches.isEmpty else { return result }
        let end = count >= matches.count ? text.endIndex : matches[count - 1].range.upperBound
        guard let attributedEnd = AttributedString.Index(end, within: result) else { return result }
        result[result.startIndex..<attributedEnd].backgroundColor = ReadLabStyle.sky
        result[result.startIndex..<attributedEnd].underlineStyle = .single
        return result
    }
}

/// Other readings of the same audio, keyed by word position in the displayed transcript.
struct SpeechWordAlternatives {
    struct Segment {
        let range: NSRange
        let alternatives: [String]
    }

    private var wordsByPosition: [Int: Set<Substring>] = [:]

    init(text: String = "", segments: [Segment] = [], transcripts: [String] = []) {
        let words = StoryText.words(in: text)
        for segment in segments where !segment.alternatives.isEmpty {
            guard let range = Range(segment.range, in: text),
                  let word = StoryText.words(in: String(text[range])).onlyWord else { continue }
            let index = StoryText.wordCount(in: String(text[..<range.lowerBound]))
            guard words.indices.contains(index), words[index] == word else { continue }
            for alternative in segment.alternatives {
                if let word = StoryText.words(in: alternative).onlyWord {
                    wordsByPosition[index, default: []].insert(word)
                }
            }
        }
        // Only use whole-transcript candidates with a single substitution and no shifted words.
        for transcript in transcripts {
            let candidate = StoryText.words(in: transcript)
            guard words.count == candidate.count,
                  let index = words.indices.first(where: { words[$0] != candidate[$0] }),
                  words[(index + 1)...].elementsEqual(candidate[(index + 1)...]) else { continue }
            wordsByPosition[index, default: []].insert(candidate[index])
        }
    }

    func contains(_ expected: Substring, at position: Int) -> Bool {
        wordsByPosition[position]?.contains(expected) == true
    }
}

private extension Array where Element == Substring {
    var onlyWord: Substring? { count == 1 ? first : nil }
}

/// Accept known recognition mix-ups only when they match the next word in the story.
private enum StoryWordMatch {
    private static let alternatives: [Substring: Set<Substring>] = [
        "could": ["cool", "call"],
        "hills": ["heels", "heals"],
        "torii": ["tori", "tory"],
        "sees": ["seas", "seize"],
        "heard": ["herd"],
        "find": ["fined"],
        "knew": ["new"],
        "new": ["knew"],
        "made": ["maid"],
        "sail": ["sale"],
        "through": ["threw"],
        "wait": ["weight"]
    ]

    static func matches(_ spoken: Substring, expected: Substring) -> Bool {
        spoken == expected || alternatives[expected]?.contains(spoken) == true
    }
}

/// Tracks which words in a recognition request have already moved the reading cursor.
struct StorySpeechCursor {
    private var previousTranscript: [Substring] = []
    private var consumedWords = 0

    mutating func advance(transcript: String, target: [Substring], from wordCount: Int, alternatives: SpeechWordAlternatives = .init()) -> Int {
        guard target.indices.contains(wordCount) else { return wordCount }
        let words = StoryText.words(in: transcript)
        // Keep the cursor when a partial result temporarily loses its trailing words.
        if words.count < previousTranscript.count && previousTranscript.starts(with: words) { return wordCount }
        let start = unconsumedStart(in: words, expecting: target[wordCount], alternatives: alternatives)
        previousTranscript = words
        consumedWords = start

        var next = wordCount
        for index in start..<words.count where next < target.count {
            // Ignore filler and corrections until the next required word is heard.
            guard StoryWordMatch.matches(words[index], expected: target[next]) ||
                  alternatives.contains(target[next], at: index) else { continue }
            next += 1
            consumedWords = index + 1
        }
        return next
    }

    private func unconsumedStart(in words: [Substring], expecting nextWord: Substring, alternatives: SpeechWordAlternatives) -> Int {
        // Partial transcripts are cumulative, but the recognizer can revise earlier text.
        let prefix = zip(previousTranscript, words).prefix { $0 == $1 }.count
        guard prefix < consumedWords else { return consumedWords }
        // Speech can replace an earlier phrase with a new fragment after a pause.
        if prefix == 0, let first = words.first,
           StoryWordMatch.matches(first, expected: nextWord) || alternatives.contains(nextWord, at: 0) { return 0 }
        let changes = words.difference(from: previousTranscript)
        let removed = Set(changes.removals.compactMap { change -> Int? in
            guard case let .remove(offset, _, _) = change, offset < consumedWords else { return nil }
            return offset
        })
        let lastRetained = (0..<consumedWords).last { !removed.contains($0) }
        guard let lastRetained else { return 0 } // A fresh fragment can start at the next target word.

        var start = lastRetained + 1 - removed.filter { $0 < lastRetained }.count
        var replacedTail = consumedWords - lastRetained - 1
        for change in changes.insertions {
            guard case let .insert(offset, _, _) = change else { continue }
            if offset < start { start += 1 }
            else if offset == start && replacedTail > 0 { start += 1; replacedTail -= 1 }
        }
        return start
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

    /// Credits newly heard words without erasing the part the child has already read.
    mutating func updateStoryReading(transcript: String, cursor: inout StorySpeechCursor, in story: ReadingStory, alternatives: SpeechWordAlternatives = .init()) -> Bool {
        guard path == .stories, !completed, !showingQuestions,
              var reading = storyReading, !reading.paragraphComplete,
              story.sections.indices.contains(sectionIndex),
              story.sections[sectionIndex].indices.contains(reading.paragraphIndex) else { return false }
        let target = StoryText.words(in: story.sections[sectionIndex][reading.paragraphIndex])
        let next = cursor.advance(transcript: transcript, target: target, from: reading.wordCount, alternatives: alternatives)
        guard next > reading.wordCount else { return false }
        reading.wordCount = next
        reading.paragraphComplete = next == target.count
        if reading.paragraphComplete { practiced += 1 }
        storyReading = reading
        return reading.paragraphComplete
    }

    /// Carry unconsumed words into the next paragraph while the same microphone request is active.
    mutating func readStoryTranscript(_ transcript: String, cursor: inout StorySpeechCursor, in story: ReadingStory, alternatives: SpeechWordAlternatives = .init()) -> [String] {
        var completedParagraphs: [String] = []
        while updateStoryReading(transcript: transcript, cursor: &cursor, in: story, alternatives: alternatives) {
            if let reading = storyReading {
                completedParagraphs.append(story.sections[sectionIndex][reading.paragraphIndex])
            }
            advanceStoryParagraph(in: story)
        }
        return completedParagraphs
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
