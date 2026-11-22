import Foundation

struct ReadingTheme: Identifiable, Equatable {
    let id: String
    let path: ReadingPath
    let title: String
    let detail: String
    let cover: String

    static func themes(for path: ReadingPath) -> [Self] {
        if path == .stories { return ReadLabIllustratedStories.themes }
        return all.filter { $0.path == path }
    }
    static func find(_ id: String) -> Self {
        all.first { $0.id == id } ?? all[0]
    }
    static let all: [Self] = [
        .init(id: "space", path: .hearing, title: "Space", detail: "Collections of words and scientific terminology", cover: "SpaceCover"),
        .init(id: "nature", path: .hearing, title: "Nature", detail: "Listen to the world growing around you", cover: "NatureCover"),
        .init(id: "animals", path: .words, title: "Animals", detail: "Collection of animal words", cover: "AnimalsCover"),
        .init(id: "jobs", path: .words, title: "Jobs", detail: "Meet the people who make things happen", cover: "JobsCover"),
        .init(id: "journey", path: .stories, title: "Journey to the West", detail: "A little adventure, one page at a time", cover: "JourneyCover"),
        .init(id: "tori", path: .stories, title: "tori’s Path", detail: "Follow a small fox on a big adventure", cover: "ToriiCover")
    ] + ReadLabIllustratedStories.themes
}

struct ReadingPrompt: Equatable {
    let syllables: [String]
    let text: String

    init(_ text: String, _ syllables: String) {
        self.text = text
        self.syllables = syllables.components(separatedBy: "·")
    }
}

struct StoryQuestion: Equatable {
    let text: String
    let options: [String]
    let answer: Int
    let hint: String
}

struct ReadingStory: Equatable {
    let title: String
    let sections: [[String]]
    let questions: [StoryQuestion]
    private let legacySectionStarts: [Int]

    init(title: String, sections: [[String]], questions: [StoryQuestion]) {
        self.title = title
        self.questions = questions
        var compactSections: [[String]] = []
        var starts: [Int] = []
        for section in sections {
            starts.append(compactSections.count)
            for start in stride(from: 0, to: section.count, by: 2) {
                compactSections.append(Array(section[start..<min(start + 2, section.count)]))
            }
        }
        self.sections = compactSections
        self.legacySectionStarts = starts
    }

    func sectionIndex(forLegacySection index: Int) -> Int {
        legacySectionStarts[min(max(0, index), legacySectionStarts.count - 1)]
    }
}

enum ReadLabLibrary {
    static func prompts(theme: String, level: Int) -> [ReadingPrompt] {
        let tier = min(4, max(0, level - 1))
        if theme == "space" || theme == "nature" {
            let space = [
                ["sun", "moon", "star", "sky", "light", "night"],
                ["planet", "rocket", "comet", "orbit", "solar", "starlight"],
                ["a bright star", "the full moon", "a red planet", "the small rocket", "a long orbit", "the night sky"],
                ["The rocket flies high.", "The moon shines at night.", "A comet crosses the sky.", "We can see the stars.", "The sun gives us light.", "Our planet is blue."],
                ["The little rocket travels past the moon.", "A bright comet leaves a trail of light.", "Our blue planet moves around the sun.", "The stars sparkle above the quiet world.", "The astronaut waves from the small window.", "We imagine a journey beyond the stars."]
            ]
            let nature = [
                ["tree", "rain", "leaf", "seed", "bird", "pond"],
                ["flower", "river", "forest", "garden", "sunshine", "rainbow"],
                ["a green leaf", "the tall tree", "a small seed", "the blue bird", "a red flower", "the soft rain"],
                ["The rain helps trees grow.", "A bird sits on a branch.", "The seed needs some water.", "A river runs through the wood.", "The leaves dance in the wind.", "A flower opens in the sun."],
                ["The little seed grows into a beautiful tree.", "A gentle shower waters the thirsty garden.", "The river carries leaves towards the sea.", "We watch a tiny bird building its nest.", "The flowers turn their faces towards the sunshine.", "After the rain a rainbow fills the sky."]
            ]
            return (theme == "space" ? space : nature)[tier].map { ReadingPrompt($0, $0) }
        }
        let animals: [[ReadingPrompt]] = [
            [.init("rabbit", "rab·bit"), .init("tiger", "ti·ger"), .init("zebra", "ze·bra"), .init("panda", "pan·da"), .init("otter", "ot·ter"), .init("parrot", "par·rot")],
            [.init("elephant", "el·e·phant"), .init("butterfly", "but·ter·fly"), .init("kangaroo", "kan·ga·roo"), .init("octopus", "oc·to·pus"), .init("pelican", "pel·i·can"), .init("ladybird", "la·dy·bird")],
            [.init("alligator", "al·li·ga·tor"), .init("a red rabbit", "a red rab·bit"), .init("a big tiger", "a big ti·ger"), .init("a small zebra", "a small ze·bra"), .init("a shy panda", "a shy pan·da"), .init("a wet otter", "a wet ot·ter")],
            [.init("hippopotamus", "hip·po·pot·a·mus"), .init("a small elephant", "a small el·e·phant"), .init("the bright butterfly", "the bright but·ter·fly"), .init("a small kangaroo", "a small kan·ga·roo"), .init("a shy octopus", "a shy oc·to·pus"), .init("the white pelican", "the white pel·i·can")],
            [.init("a very small rabbit", "a ver·y small rab·bit"), .init("a very big tiger", "a ver·y big ti·ger"), .init("a little red parrot", "a lit·tle red par·rot"), .init("a very shy panda", "a ver·y shy pan·da"), .init("the little young zebra", "the lit·tle young ze·bra"), .init("a very wet otter", "a ver·y wet ot·ter")]
        ]
        let jobs: [[ReadingPrompt]] = [
            [.init("baker", "ba·ker"), .init("doctor", "doc·tor"), .init("teacher", "teach·er"), .init("farmer", "farm·er"), .init("painter", "paint·er"), .init("singer", "sing·er")],
            [.init("firefighter", "fire·fight·er"), .init("astronaut", "as·tro·naut"), .init("a baker", "a ba·ker"), .init("a teacher", "a teach·er"), .init("the farmer", "the farm·er"), .init("a painter", "a paint·er")],
            [.init("photographer", "pho·tog·ra·pher"), .init("a kind doctor", "a kind doc·tor"), .init("the firefighter", "the fire·fight·er"), .init("the astronaut", "the as·tro·naut"), .init("a great teacher", "a great teach·er"), .init("a young singer", "a young sing·er")],
            [.init("the happy painter", "the hap·py paint·er"), .init("a friendly teacher", "a friend·ly teach·er"), .init("a busy farmer", "a bus·y farm·er"), .init("a helpful doctor", "a help·ful doc·tor"), .init("a careful baker", "a care·ful ba·ker"), .init("a famous singer", "a fa·mous sing·er")],
            [.init("a helpful firefighter", "a help·ful fire·fight·er"), .init("a happy astronaut", "a hap·py as·tro·naut"), .init("the very kind teacher", "the ver·y kind teach·er"), .init("a very good farmer", "a ver·y good farm·er"), .init("a very skilled baker", "a ver·y skilled ba·ker"), .init("a very good singer", "a ver·y good sing·er")]
        ]
        return (theme == "jobs" ? jobs : animals)[tier]
    }

    static func story(theme: String, level: Int) -> ReadingStory {
        if let illustrated = ReadLabIllustratedStories.story(theme: theme, level: level) { return illustrated }
        let tier = min(5, max(1, level))
        if theme == "tori" { return foxStory(level: tier) }
        return monkeyStory(level: tier)
    }

    private static func monkeyStory(level: Int) -> ReadingStory {
        let sections: [[String]]
        switch level {
        case 1:
            sections = [["Monkey has a red bag. He wants to go west.", "He sees a river. His friend helps him cross. They go west together."]]
        case 2:
            sections = [["Monkey packs a red bag for a long walk. He wants to visit the hills in the west.", "Soon he finds a wide river. He cannot jump across it."], ["A kind friend brings a boat. Together they cross the river.", "Monkey shares his lunch. The two friends walk towards the hills."]]
        case 3:
            sections = [["One bright morning, Monkey packed a red bag and set out for the western hills.", "He followed a winding path until he reached a river. The water was too deep to cross on foot.", "Monkey sat on a stone and thought. Then he heard a friendly voice."], ["A traveler offered him a place in a small boat. Monkey climbed in carefully.", "On the far bank, Monkey shared his peaches with the traveler to say thank you.", "They decided to walk together. The journey felt easier with a friend beside him."]]
        case 4:
            sections = [["At sunrise, Monkey set out towards the western hills, carrying a red bag filled with peaches and a carefully folded map.", "He believed that speed was the most important part of a journey. Before midday, however, a broad river brought him to a sudden halt.", "He tried to leap across, but the far bank lay well beyond his reach. For the first time that morning, he stood still and listened."], ["A traveler nearby was repairing a wooden boat. Instead of demanding a ride, Monkey offered to help mend the sail.", "They worked together until the boat was ready. With the sail catching the breeze, they crossed safely to the opposite bank.", "Monkey opened his bag and shared the peaches. He discovered that patience and kindness could take him further than speed."], ["The traveler pointed out a safer path through the hills. It was longer than the route on Monkey’s map, but it led around a steep cliff.", "Monkey folded the map and thanked his new companion. This time, he chose to walk slowly enough to notice the world around him.", "By evening, the western hills glowed gold. Reaching them felt wonderful, yet remembering the friend he had made felt even better."]]
        default:
            sections = [["Monkey had always imagined that a great journey would be measured by distance. With a red bag of peaches and a map of the western hills, he departed before the village had stirred.", "The path climbed through misty woodland, then descended to a river swollen by recent rain. Across the water, the route on his map continued as though nothing stood in its way.", "His first attempt to leap between the banks ended in a shower of mud. Frustrated, he nearly turned back, convinced that the river had ruined his adventure."], ["Only when he stopped did he notice a traveler patiently repairing a boat. The stranger had no map, but knew every bend of the river.", "Monkey offered his help. As they patched the sail, the traveler explained that a useful plan must leave room for things its maker cannot foresee.", "They launched the boat together. In the middle of the river, Monkey realised that accepting help had carried him further than his proudest leap."], ["On the opposite bank, Monkey shared his peaches. The traveler described a route that circled a dangerous cliff, though taking it would add several hours to the walk.", "Monkey studied his map. Its neat line promised a quick arrival, but it said nothing about the broken ground ahead.", "He chose the longer route. What had first seemed like a delay now felt like an opportunity to understand the landscape."], ["By dusk, Monkey reached a ridge overlooking the western hills. The destination was as beautiful as he had hoped, yet it no longer seemed the only purpose of the journey.", "He added the river, the safe path, and a tiny drawing of a boat to his map. Someone following him might now travel with greater confidence.", "Then he wrote one sentence beneath the drawing: a journey grows richer when we allow others to change the way we see it."]]
        }
        return .init(title: "Journey to the West", sections: sections, questions: [
            .init(text: "Which way does Monkey want to go?", options: ["North", "West", "East"], answer: 1, hint: "Look for the direction in the first section."),
            .init(text: "How does Monkey cross the river?", options: ["In a boat", "On a horse", "By jumping"], answer: 0, hint: "His friend helps him cross the water."),
            .init(text: level > 2 ? "What does Monkey learn from his journey?" : "Who helps Monkey?", options: level > 2 ? ["He must always hurry", "Maps are never useful", "Help and friendship matter"] : ["A dragon", "His friend", "A bird"], answer: level > 2 ? 2 : 1, hint: "Think about what becomes easier when they work together.")
        ])
    }

    private static func foxStory(level: Int) -> ReadingStory {
        let sections: [[String]]
        switch level {
        case 1:
            sections = [["Tori is a small fox. She sees a red gate.", "A bird is lost. tori helps it find its nest. The nest is in a tree."]]
        case 2:
            sections = [["Tori the fox walks to a red gate. A little bird calls from the grass.", "The bird cannot find its nest. tori looks up at the trees."], ["She sees a nest in an old tree. She shows the bird the way.", "The bird sings to say thank you. tori walks home with a happy heart."]]
        case 3:
            sections = [["Tori was a curious little fox who liked to explore the path beyond the red gate.", "One afternoon, she heard a tiny bird calling from the long grass. It had lost its way home.", "tori wanted to keep exploring, but the bird looked worried. She decided to stay and help."], ["She searched the trees until she spotted a nest among the branches of an old oak.", "The bird followed her gaze and flew up to its family. Soon the branches were full of cheerful singing.", "tori went home a little later than planned. Helping someone had made the day an adventure after all."]]
        case 4:
            sections = [["Beyond the red gate lay a path tori had never explored. She set out early, determined to discover where it ended.", "A faint call interrupted her walk. In the grass, a young bird was searching for the tree that held its nest.", "tori glanced towards the distant hills. If she stopped, she might not reach them before sunset."], ["She decided that the hills could wait. Rather than searching at random, she asked the bird what it remembered about home.", "The bird described a crooked branch and leaves shaped like little hands. tori recognised the old oak beside the stream.", "They followed the sound of running water until the oak appeared. High above them, a family of birds called in reply."], ["The young bird flew safely into its nest. tori rested beneath the tree, listening to the music of the stream and the leaves.", "She had not discovered the end of the path, but she had discovered how carefully listening could solve a problem.", "The next morning, she returned to the red gate. The hills were still there, and the birds sang as she passed."]]
        default:
            sections = [["tori regarded the red gate as a promise: beyond it, she believed, waited a discovery worthy of a proper explorer. She carried no luggage except a determination to reach the distant hills.", "Her journey had scarcely begun when a hesitant call rose from the grass. A young bird, separated from its family, could remember the shape of its nest but not the way back to it.", "tori hesitated. The hills were far away, and every moment spent searching would shorten the daylight available for her own adventure."], ["She asked the bird to describe what it remembered. At first, the answer seemed unhelpful: moving leaves, a crooked branch, and a constant whisper beneath the tree.", "Instead of dismissing these clues, tori considered them together. The whisper might be water, and the crooked branch might belong to the old oak beside the stream.", "They followed a narrow trail through the ferns. Gradually, the whisper became the unmistakable sound of running water."], ["The old oak stood at a bend in the stream. Above a crooked branch, a nest sheltered a family of birds whose worried calls changed to joyful song.", "As the young bird flew home, tori understood that its imperfect memories had contained everything they needed. The clues had become useful only when someone listened with patience.", "She rested beneath the oak. The hills remained hidden beyond the trees, but the place where she sat no longer seemed less worthy of discovery."], ["On her way home, tori marked the trail with a few fallen stones so she could find the oak again without disturbing the woodland.", "She would try for the hills another day. For now, she carried a different understanding of exploration: the unfamiliar can be found by paying attention to what is already nearby.", "When she passed beneath the red gate, the evening light made it glow. It still looked like a promise, though she was no longer certain that every promise needed a distant destination."]]
        }
        return .init(title: "tori’s Path", sections: sections, questions: [
            .init(text: "What kind of animal is tori?", options: ["A rabbit", "A fox", "A bear"], answer: 1, hint: "tori is introduced at the start of the story."),
            .init(text: "Where is the bird’s nest?", options: ["In a tree", "Under a bridge", "Inside the gate"], answer: 0, hint: "tori looks up to find the bird’s home."),
            .init(text: level > 2 ? "What helps tori find the nest?" : "What colour is the gate?", options: level > 2 ? ["Running away", "Ignoring the bird", "Listening and looking carefully"] : ["Blue", "Yellow", "Red"], answer: 2, hint: level > 2 ? "tori pays attention to the bird and the world around her." : "Read the first sentence again.")
        ])
    }
}
