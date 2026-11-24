import Foundation

/// Compares dictionary pronunciations of transcribed English words.
struct PhoneticMatcher {
    struct VowelPair: Hashable {
        private let first: String
        private let second: String

        init(_ first: String, _ second: String) {
            self.first = min(first, second)
            self.second = max(first, second)
        }
    }

    struct Configuration {
        /// One substitution from this set is allowed within an otherwise identical pronunciation.
        var allowedVowelPairs: Set<VowelPair> = []
        /// Directional recognition errors, scoped to Growing Reader's next expected word.
        var storyAlternatives: [Substring: Set<Substring>] = [:]

        static let growingReader = Configuration(storyAlternatives: [
            "hills": ["heels"], "walking": ["working"], "reach": ["rich"],
            "slip": ["sleep"], "branch": ["brunch"], "branches": ["brunches"],
            "ball": ["bowl"], "sitting": ["setting"], "warm": ["worm"],
            "chirp": ["chip"], "chirps": ["chips", "chip"], "chirping": ["chipping"],
            "twigs": ["tweaks", "tweets"], "fall": ["fault"],
            "walks": ["walk", "works"], "picks": ["pics", "pizza"]
        ])
    }

    let configuration: Configuration

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // Parse the bundled lexicon once, shared by all readers and configurations.
    private static let pronunciations: [Substring: [[Substring]]] = {
        guard let url = Bundle.main.url(forResource: "cmudict", withExtension: "txt")
                ?? Bundle.main.url(forResource: "cmudict", withExtension: "txt", subdirectory: "Pronunciation"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return [:] }

        var entries: [Substring: [[Substring]]] = [:]
        entries.reserveCapacity(125_000)
        for line in contents.split(separator: "\n") where !line.hasPrefix(";;;") {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let headword = fields.first else { continue }
            let phones = fields.dropFirst().prefix { !$0.hasPrefix("#") }
            guard !phones.isEmpty else { continue }
            let word = headword.prefix { $0 != "(" }
            entries[word, default: []].append(Array(phones))
        }
        return entries
    }()

    func matches(_ recognized: Substring, expected: Substring) -> Bool {
        guard let spoken = StoryText.words(in: String(recognized)).only,
              let target = StoryText.words(in: String(expected)).only else { return false }
        if spoken == target { return true }
        if configuration.storyAlternatives[target]?.contains(spoken) == true { return true }
        guard let recognizedVariants = Self.pronunciations[spoken],
              let expectedVariants = Self.pronunciations[target] else { return false }
        return recognizedVariants.contains { heard in
            expectedVariants.contains { intended in matches(heard, intended) }
        }
    }

    private func matches(_ heard: [Substring], _ intended: [Substring]) -> Bool {
        if heard == intended { return true }
        guard !configuration.allowedVowelPairs.isEmpty, heard.count == intended.count else { return false }
        var substituted = false
        for index in heard.indices where heard[index] != intended[index] {
            // Keep both ends, all consonants, and vowel stress fixed for near matches.
            guard !substituted, index > 0, index < heard.count - 1,
                  let stress = heard[index].last, "012".contains(stress), stress == intended[index].last,
                  configuration.allowedVowelPairs.contains(
                    VowelPair(String(heard[index].dropLast()), String(intended[index].dropLast()))
                  ) else { return false }
            substituted = true
        }
        return substituted
    }
}

private extension Array where Element == Substring {
    var only: Substring? { count == 1 ? first : nil }
}
