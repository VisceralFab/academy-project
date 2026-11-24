import Foundation
import SwiftUI

/// Uses the same word boundaries for recognition, the counter, and highlighting.
enum StoryText {
    private static let wordPattern = #/[\p{L}\p{M}\p{N}]+(?:['’‘ʼ＇][\p{L}\p{M}\p{N}]+)*/#

    static func words(in text: String) -> [Substring] {
        // Preserve contractions and possessives as dictionary words. Other paths keep
        // their existing SpeechMatch normalization and exact prompt comparison.
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        return folded.matches(of: wordPattern).map {
            Substring($0.output.replacingOccurrences(of: "’", with: "'")
                .replacingOccurrences(of: "‘", with: "'")
                .replacingOccurrences(of: "ʼ", with: "'")
                .replacingOccurrences(of: "＇", with: "'"))
        }
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

    func contains(_ expected: Substring, at position: Int, using matcher: PhoneticMatcher) -> Bool {
        wordsByPosition[position]?.contains { matcher.matches($0, expected: expected) } == true
    }
}

private extension Array where Element == Substring {
    var onlyWord: Substring? { count == 1 ? first : nil }
}

/// Tracks which words in a recognition request have already moved the reading cursor.
struct StorySpeechCursor {
    private var previousTranscript: [Substring] = []
    private var consumedWords = 0
    private var creditedWords: [Int: (expected: Substring, recognized: Substring)] = [:]
    private let phonetics = PhoneticMatcher(configuration: .growingReader)

    mutating func advance(transcript: String, target: [Substring], from wordCount: Int, alternatives: SpeechWordAlternatives = .init()) -> Int {
        guard target.indices.contains(wordCount) else { return wordCount }
        let words = StoryText.words(in: transcript)
        // A new spelling of the same sound may revise a credited word, but cannot credit it twice.
        let prefix = zip(previousTranscript, words).enumerated().prefix { index, pair in
            if pair.0 == pair.1 { return true }
            // Compare revisions against the original credited word, including asymmetric
            // exceptions such as walks → walk/works, so they cannot credit a word twice.
            if let credited = creditedWords[index] {
                // Preserve the actual accepted spelling too: it can have been credited
                // via an aligned Speech alternative or the contextual picks up rule.
                return (pair.0 == credited.recognized || phonetics.matches(pair.0, expected: credited.expected)) &&
                    (pair.1 == credited.recognized || phonetics.matches(pair.1, expected: credited.expected))
            }
            return phonetics.matches(pair.1, expected: pair.0)
        }.count
        if words.count < previousTranscript.count && prefix == words.count { return wordCount }
        let start = unconsumedStart(in: words, sharedPrefix: prefix, expecting: target[wordCount], alternatives: alternatives)
        previousTranscript = words
        consumedWords = start
        creditedWords = creditedWords.filter { $0.key < start }

        var next = wordCount
        for index in start..<words.count where next < target.count {
            // Ignore filler and corrections until the next required word is heard.
            let picksUp = target[next] == "picks" && words[index] == "pick" &&
                target.indices.contains(next + 1) && target[next + 1] == "up" &&
                words.indices.contains(index + 1) && words[index + 1] == "up"
            guard phonetics.matches(words[index], expected: target[next]) || picksUp ||
                  alternatives.contains(target[next], at: index, using: phonetics) else { continue }
            creditedWords[index] = (expected: target[next], recognized: words[index])
            next += 1
            consumedWords = index + 1
        }
        return next
    }

    private func unconsumedStart(in words: [Substring], sharedPrefix prefix: Int, expecting nextWord: Substring, alternatives: SpeechWordAlternatives) -> Int {
        guard prefix < consumedWords else { return consumedWords }
        // Speech can replace an earlier phrase with a new fragment after a pause.
        if prefix == 0, let first = words.first,
           phonetics.matches(first, expected: nextWord) || alternatives.contains(nextWord, at: 0, using: phonetics) { return 0 }
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
