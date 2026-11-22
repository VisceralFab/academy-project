import Foundation

/// Each caption is paired with the artwork at the same position in the book.
enum ReadLabIllustratedStories {
    static let themes: [ReadingTheme] = [
        .init(id: "monkey-adventure", path: .stories, title: "Monkey’s Adventure",
              detail: "A walk in the jungle leads to a new friend.", cover: "MonkeyAdventure01"),
        .init(id: "journey-to-west", path: .stories, title: "Journey to the West",
              detail: "Monkey sets off with a red bag and a map.", cover: "JourneyWest01"),
        .init(id: "poor-little-bird", path: .stories, title: "Poor Little Bird",
              detail: "Monkey helps a little bird save its nest.", cover: "PoorLittleBird01")
    ]

    static func story(theme: String, level: Int) -> ReadingStory? {
        guard let entry = themes.first(where: { $0.id == theme }) else { return nil }
        let book: (captions: [String], shortCaptions: [String], extraDetails: [(page: Int, text: String)], questions: [StoryQuestion])
        switch theme {
        case "monkey-adventure": book = monkey
        case "journey-to-west": book = journey
        default: book = bird
        }
        var captions = level <= 1 ? book.shortCaptions : book.captions
        // Higher levels add a detail to existing pages, keeping their illustrations and order.
        for detail in book.extraDetails.prefix(max(0, level - 2)) {
            captions[detail.page] += " " + detail.text
        }
        let questionCount = level < 3 ? 3 : (level == 3 ? 4 : 6)
        return ReadingStory(title: entry.title, sections: [captions], questions: Array(book.questions.prefix(questionCount)))
    }

    static func artwork(for theme: ReadingTheme, page: Int) -> String {
        guard themes.contains(where: { $0.id == theme.id }) else { return theme.cover }
        return String(theme.cover.dropLast(2)) + String(format: "%02d", min(9, max(1, page)))
    }

    private static let monkey = (
        captions: [
            "Monkey walks along a jungle path.",
            "He finds a tree full of yellow bananas.",
            "He picks one and eats it.",
            "Just then, Monkey hears a loud rustle behind the tree.",
            "A little elephant appears, looking worried.",
            "Elephant’s favorite ball is stuck high among the branches.",
            "Monkey carefully climbs the tree and reaches for the ball.",
            "He passes it to Elephant, who catches it with his trunk.",
            "The two new friends spend the afternoon playing beneath the tree."
        ],
        shortCaptions: [
            "Monkey walks along a jungle path.",
            "He finds a banana tree.",
            "He eats a banana.",
            "Monkey hears a noise.",
            "A worried elephant appears.",
            "His ball is stuck in the tree.",
            "Monkey climbs up to get it.",
            "Elephant catches it with his trunk.",
            "The new friends play with the ball."
        ],
        extraDetails: [
            (page: 1, text: "The ripe fruit hangs from the branches."),
            (page: 3, text: "He stops to see who is there."),
            (page: 7, text: "Elephant lifts the ball into the air.")
        ],
        questions: [
            q("Where does the story take place?", ["Forest", "Jungle", "Park"], 1, "Look at the first page."),
            q("What fruit did Monkey eat?", ["Apple", "Melon", "Banana"], 2, "The fruit was yellow."),
            q("Which animal did Monkey meet?", ["Elephant", "Monkey", "Iguana"], 0, "His new friend has a trunk."),
            q("How was Elephant feeling?", ["Worried", "Happy", "Angry"], 0, "His ball was stuck."),
            q("What did Elephant use to catch the ball?", ["Leg", "Head", "Trunk"], 2, "Think about Elephant’s long nose."),
            q("What did they play with?", ["A ball", "Leaves", "Roots"], 0, "Monkey got it out of the tree.")
        ]
    )

    private static let journey = (
        captions: [
            "Monkey packs his red bag and heads west.",
            "A wide river blocks his way.",
            "A friendly elephant helps him cross in a boat.",
            "On the other bank, the path divides in two.",
            "The west trail ends at a fallen tree.",
            "Monkey has an idea that could change his life.",
            "He takes out his treasure map.",
            "Monkey starts to dig with his shovel.",
            "Monkey finds his ancestors’ treasure!"
        ],
        shortCaptions: [
            "Monkey packs his red bag and heads west.",
            "He finds a wide river.",
            "Elephant helps him cross in a boat.",
            "The path splits in two.",
            "A fallen tree blocks the trail.",
            "Monkey has an idea.",
            "He takes out his treasure map.",
            "Monkey digs with his shovel.",
            "He finds his ancestors’ treasure!"
        ],
        extraDetails: [
            (page: 1, text: "The water is too deep to walk across."),
            (page: 5, text: "What if the fallen tree is a clue?"),
            (page: 7, text: "His shovel strikes the lid of a chest.")
        ],
        questions: [
            q("Which way is Monkey going?", ["West", "East", "North"], 0, "Read the first page again."),
            q("What did Elephant use to help Monkey cross?", ["A car", "A boat", "A train"], 1, "What floats on a river?"),
            q("How many paths were there?", ["Two", "One", "Three"], 0, "The path split on the other bank."),
            q("What was at the end of the trail?", ["A fallen tree", "A tall tree", "A little tree"], 0, "Something was blocking the trail."),
            q("Who did the treasure belong to?", ["His parents", "His siblings", "His ancestors"], 2, "Read the last page again."),
            q("How did Monkey find the treasure?", ["With a map", "With his imagination", "By luck"], 0, "What did he take out before digging?")
        ]
    )

    private static let bird = (
        captions: [
            "Monkey hears a little bird.",
            "He finds its nest in a tree.",
            "The bird is keeping his egg warm.",
            "Some twigs are falling out of the bird’s nest.",
            "The nest starts to tilt to the left.",
            "Monkey notices that the little home is no longer strong enough.",
            "Monkey gathers twigs to help the poor little bird.",
            "Together they repair the nest.",
            "With the nest safe again, the bird’s family sings happily."
        ],
        shortCaptions: [
            "Monkey hears a little bird.",
            "He finds a nest in a tree.",
            "The bird keeps his egg warm.",
            "Twigs fall out of the nest.",
            "The nest tilts to the left.",
            "The nest is not safe.",
            "Monkey gets some twigs.",
            "They fix the nest together.",
            "The bird’s family sings happily."
        ],
        extraDetails: [
            (page: 2, text: "He stays close to protect it."),
            (page: 6, text: "He picks the strongest ones he can find."),
            (page: 7, text: "They weave the twigs into the nest.")
        ],
        questions: [
            q("What was the bird doing?", ["Singing", "Keeping an egg warm", "Flying"], 1, "Look inside the nest."),
            q("How did Monkey notice the bird?", ["He heard it", "He saw it", "He played with it"], 0, "Read the first page again."),
            q("What was falling out of the nest?", ["Leaves", "Roots", "Twigs"], 2, "What did Monkey gather to repair it?"),
            q("What did they do at the end?", ["Danced", "Sang", "Talked"], 1, "Read the last page again."),
            q("Which way did the nest tilt?", ["To the right", "To the left", "Straight down"], 1, "Look at the nest before Monkey helps."),
            q("Did Monkey help the bird?", ["Yes", "No"], 0, "Think about what they did together.")
        ]
    )

    private static func q(_ text: String, _ options: [String], _ answer: Int, _ hint: String) -> StoryQuestion {
        StoryQuestion(text: text, options: options, answer: answer, hint: hint)
    }
}
