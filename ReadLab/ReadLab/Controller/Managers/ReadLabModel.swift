import Foundation
import Observation

enum ReadingPath: String, CaseIterable, Codable, Identifiable {
    case hearing, words, stories
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hearing: "Hearing sounds"
        case .words: "First words"
        case .stories: "Growing readers"
        }
    }
    var question: String {
        switch self {
        case .hearing: "What shall we hear today?"
        case .words: "What shall we explore today?"
        case .stories: "What shall we read today?"
        }
    }
    var detail: String {
        switch self {
        case .hearing: "Explore letters, sounds, syllables, and rhymes through playful activities."
        case .words: "Combine syllables, discover familiar words, and read your first sentences."
        case .stories: "Discover engaging stories and grow your reading comprehension."
        }
    }
    var mascot: String {
        switch self { case .hearing: "Elephant"; case .words: "Parrot"; case .stories: "Monkey" }
    }
    var symbol: String {
        switch self { case .hearing: "ear.badge.waveform"; case .words: "textformat.abc"; case .stories: "book.pages" }
    }
}

struct ReadLabChildProfile: Equatable, Codable {
    var childName = ""
    var ageRange: ReadLabAgeRange?
    var readingFamiliarity: ReadLabReadingFamiliarity?
    var isValid: Bool {
        ageRange != nil && !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum ReadLabAgeRange: String, CaseIterable, Identifiable, Codable {
    case fourFive = "4–5", sixSeven = "6–7", eightNine = "8–9", tenPlus = "10+"
    var id: String { rawValue }

    var startingLevel: Int {
        switch self {
        case .fourFive: 1
        case .sixSeven, .eightNine: 3
        case .tenPlus: 5
        }
    }

    func storyEdition(at level: Int) -> Self {
        let editions = Self.allCases
        let startingEdition = editions.firstIndex(of: self) ?? 0
        let index = startingEdition + level - startingLevel
        return editions[min(editions.count - 1, max(0, index))]
    }
}

enum ReadLabReadingFamiliarity: String, CaseIterable, Identifiable, Codable {
    case notIndependent = "Not reading independently", learning = "Learning to read", independent = "Reading independently"
    var id: String { rawValue }
    var detail: String {
        switch self {
        case .notIndependent: "Enjoys sounds, pictures, and shared stories."
        case .learning: "Reads short sentences with a little help."
        case .independent: "Reads stories alone and is building fluency."
        }
    }
}

struct ReadLabLearningPreferences: Equatable, Codable {
    var diagnosis: ReadLabDiagnosis = .noneReported
    var trackReadingProgress = true
    var useDyslexicFont = false
}

enum ReadLabDiagnosis: String, CaseIterable, Identifiable, Codable {
    case noneReported = "No diagnosed learning difficulty"
    case diagnosed = "Has a diagnosed learning difficulty"
    var id: String { rawValue }
    var detail: String {
        switch self {
        case .noneReported: "No learning difficulty has been reported."
        case .diagnosed: "A learning difficulty has been diagnosed by a specialist."
        }
    }
}

/// Age sets the initial level. Practice then adapts it independently for each path.
struct AdaptiveDifficulty: Codable, Equatable {
    private(set) var level: Int
    private(set) var successStreak = 0
    private(set) var mistakes = 0
    private var abandonedActivities: Int?

    init(level: Int = 1) {
        self.level = level
    }

    @discardableResult
    mutating func record(success: Bool) -> Bool {
        let previous = level
        if success {
            successStreak += 1
            mistakes = 0
            if successStreak >= 3 {
                level = min(5, level + 1)
                successStreak = 0
            }
        } else {
            successStreak = 0
            mistakes += 1
            if mistakes >= 2 {
                level = max(1, level - 1)
                mistakes = 0
            }
        }
        if previous != level { resetAbandonments() }
        return previous != level
    }

    mutating func recordAbandonment() {
        let count = (abandonedActivities ?? 0) + 1
        if count >= 2 {
            level = max(1, level - 1)
            mistakes = 0
            successStreak = 0
            resetAbandonments()
        } else {
            abandonedActivities = count
        }
    }

    mutating func resetAbandonments() {
        abandonedActivities = nil
    }
}

struct PracticeSession: Codable, Equatable, Identifiable {
    var id = UUID()
    var path: ReadingPath
    var themeID: String
    var itemIndex = 0
    var sectionIndex = 0
    var questionIndex = 0
    var storyReading: StoryReadingProgress?
    var showingQuestions = false
    var answeredCurrentItem = false
    var completed = false
    // Keep content stable across launches even if the next task changes difficulty.
    var contentLevel = 1
    // Nil identifies older sessions that must retain their original text and quiz.
    var storyAgeRange: ReadLabAgeRange?
    // Only replacements of an unfinished activity with a recorded miss count as abandonments.
    var hadDifficulty: Bool?
    var practiced = 0
    var progress: Double { completed ? 1 : min(0.95, Double(itemIndex) / 6) }
}

struct PracticeTotals: Codable, Equatable {
    var completedActivities = 0
    var successfulAnswers = 0
    var attempts = 0
}

/// One entry per exercise event, used for the carer's performance report.
struct ExerciseRecord: Codable, Equatable, Identifiable {
    enum Outcome: String, Codable {
        case correct, retry, assisted, completed
        var label: String {
            switch self {
            case .correct: "Correct"
            case .retry: "Needs another try"
            case .assisted: "Read with a grown-up"
            case .completed: "Activity completed"
            }
        }
    }
    var id = UUID()
    var date = Date()
    var path: ReadingPath
    var themeID: String
    var item: String
    var outcome: Outcome
    var level: Int
}

struct ReadLabData: Codable, Equatable {
    var hasOnboarded = false
    var profile = ReadLabChildProfile()
    var preferences = ReadLabLearningPreferences()
    var selectedPath: ReadingPath = .hearing
    var sessions: [String: PracticeSession] = [:]
    var difficulty: [String: AdaptiveDifficulty] = [:]
    var totals: [String: PracticeTotals] = [:]
    var exerciseLog: [ExerciseRecord] = []
    static let maxLogEntries = 3000

    var startingAge: ReadLabAgeRange { profile.ageRange ?? .fourFive }

    func difficulty(for path: ReadingPath) -> AdaptiveDifficulty {
        difficulty[path.rawValue] ?? AdaptiveDifficulty(level: startingAge.startingLevel)
    }
}

extension ReadLabData {
    /// Tolerant decoding: journeys saved by older versions (missing keys) still open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ReadLabData()
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? d.hasOnboarded
        profile = try c.decodeIfPresent(ReadLabChildProfile.self, forKey: .profile) ?? d.profile
        preferences = try c.decodeIfPresent(ReadLabLearningPreferences.self, forKey: .preferences) ?? d.preferences
        selectedPath = try c.decodeIfPresent(ReadingPath.self, forKey: .selectedPath) ?? d.selectedPath
        sessions = try c.decodeIfPresent([String: PracticeSession].self, forKey: .sessions) ?? d.sessions
        difficulty = try c.decodeIfPresent([String: AdaptiveDifficulty].self, forKey: .difficulty) ?? d.difficulty
        totals = try c.decodeIfPresent([String: PracticeTotals].self, forKey: .totals) ?? d.totals
        exerciseLog = try c.decodeIfPresent([ExerciseRecord].self, forKey: .exerciseLog) ?? d.exerciseLog
    }
}

@MainActor @Observable
final class ReadLabStore {
    var data: ReadLabData { didSet { persist() } }
    var storageMessage: String?
    let defaults: UserDefaults
    private let storageKey = "readlab.journey.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.data(forKey: storageKey) {
            do { data = try JSONDecoder().decode(ReadLabData.self, from: saved) }
            catch {
                data = ReadLabData()
                storageMessage = "Your saved journey could not be opened. You can set it up again."
            }
        } else { data = ReadLabData() }
    }

    func level(for path: ReadingPath) -> Int { data.difficulty(for: path).level }
    func level(forStarting theme: ReadingTheme) -> Int {
        difficultyAfterReplacingSession(path: theme.path, themeID: theme.id)?.level ?? level(for: theme.path)
    }
    func storyEdition(for level: Int) -> ReadLabAgeRange { data.startingAge.storyEdition(at: level) }

    func session(for path: ReadingPath) -> PracticeSession? {
        guard var session = data.sessions[path.rawValue] else { return nil }
        // An unattempted word exercise saved before age-based levels may still contain level 1.
        if path != .stories, data.difficulty[path.rawValue] == nil, !session.completed,
           session.itemIndex == 0, session.practiced == 0, !session.answeredCurrentItem {
            session.contentLevel = level(for: path)
        }
        return session
    }

    func start(path: ReadingPath, theme: ReadingTheme) -> PracticeSession {
        if let difficulty = difficultyAfterReplacingSession(path: path, themeID: theme.id) {
            data.difficulty[path.rawValue] = difficulty
        }
        var session = PracticeSession(path: path, themeID: theme.id, contentLevel: level(for: path))
        if ReadLabIllustratedStories.themes.contains(theme) {
            session.storyAgeRange = storyEdition(for: session.contentLevel)
        }
        update(session)
        return session
    }

    private func difficultyAfterReplacingSession(path: ReadingPath, themeID: String) -> AdaptiveDifficulty? {
        guard let previous = session(for: path), previous.themeID != themeID,
              !previous.completed, previous.hadDifficulty == true else { return nil }
        var difficulty = data.difficulty(for: path)
        difficulty.recordAbandonment()
        return difficulty
    }

    func update(_ session: PracticeSession) { data.sessions[session.path.rawValue] = session }

    @discardableResult
    func record(success: Bool, in session: inout PracticeSession, item: String) -> Bool {
        let changed = record(success: success, path: session.path, themeID: session.themeID, item: item)
        // A correct response or a downgrade already resolved the most recent difficulty.
        session.hadDifficulty = !success && !changed ? true : nil
        return changed
    }

    @discardableResult
    func record(success: Bool, path: ReadingPath, themeID: String = "", item: String = "") -> Bool {
        var difficulty = data.difficulty(for: path)
        let levelBefore = difficulty.level
        let changed = difficulty.record(success: success)
        data.difficulty[path.rawValue] = difficulty
        if data.preferences.trackReadingProgress {
            var totals = data.totals[path.rawValue, default: .init()]
            totals.attempts += 1
            if success { totals.successfulAnswers += 1 }
            data.totals[path.rawValue] = totals
            log(.init(path: path, themeID: themeID, item: item, outcome: success ? .correct : .retry, level: levelBefore))
        }
        return changed
    }

    /// A grown-up confirmed the reading; logged for the report but not used for difficulty.
    func recordAssisted(path: ReadingPath, themeID: String, item: String) {
        guard data.preferences.trackReadingProgress else { return }
        log(.init(path: path, themeID: themeID, item: item, outcome: .assisted, level: level(for: path)))
    }

    func finish(_ session: inout PracticeSession) {
        guard !session.completed else { return }
        session.completed = true
        update(session)
        if data.difficulty[session.path.rawValue] != nil {
            data.difficulty[session.path.rawValue]?.resetAbandonments()
        }
        if data.preferences.trackReadingProgress {
            data.totals[session.path.rawValue, default: .init()].completedActivities += 1
            log(.init(path: session.path, themeID: session.themeID, item: "", outcome: .completed, level: session.contentLevel))
        }
    }

    func setTracking(_ enabled: Bool) {
        data.preferences.trackReadingProgress = enabled
        if !enabled { data.totals = [:]; data.exerciseLog = [] }
    }

    private func log(_ record: ExerciseRecord) {
        data.exerciseLog.append(record)
        if data.exerciseLog.count > ReadLabData.maxLogEntries {
            data.exerciseLog.removeFirst(data.exerciseLog.count - ReadLabData.maxLogEntries)
        }
    }

    private func persist() {
        do { defaults.set(try JSONEncoder().encode(data), forKey: storageKey) }
        catch { storageMessage = "Your latest changes could not be saved. Please try again." }
    }
}

enum SpeechMatch {
    static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Match the complete prompt. Extra or missing words do not count as a successful reading.
    static func matches(_ spoken: String, target: String) -> Bool {
        let target = normalized(target)
        return !target.isEmpty && normalized(spoken) == target
    }
}
