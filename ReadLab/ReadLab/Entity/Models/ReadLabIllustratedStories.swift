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
        // Two comprehension questions per narrative block (pages 1–3, 4–6, 7–9).
        // The current UI shows them together at the end of the story.
        let questionCount = 6
        return ReadingStory(title: entry.title, sections: [captions], questions: Array(book.questions.prefix(questionCount)))
    }

    static func artwork(for theme: ReadingTheme, page: Int) -> String {
        guard themes.contains(where: { $0.id == theme.id }) else { return theme.cover }
        return String(theme.cover.dropLast(2)) + String(format: "%02d", min(9, max(1, page)))
    }

    static func quizArtwork(for themeID: String) -> String? {
        switch themeID {
        case "monkey-adventure": "MonkeyAdventureQuiz"
        case "journey-to-west", "journey": "JourneyWestQuiz"
        case "poor-little-bird": "PoorLittleBirdQuiz"
        default: nil
        }
    }

    private static let monkey = (
        captions: [
            "Monkey follows a quiet path through the jungle.",
            "He spots a tree covered in bright yellow bananas.",
            "Hungry from walking, he picks a banana and eats it.",
            "As he finishes eating, Monkey hears a sudden rustle behind the tree.",
            "A little elephant steps out. He keeps looking up at the branches.",
            "A ball is caught high above his head. Monkey begins to understand why Elephant looks worried.",
            "Monkey sees a way to help. He carefully climbs the tree towards the ball.",
            "Balancing on a branch, he gently drops the ball. Elephant catches it safely with his trunk.",
            "Once the ball is safe, Elephant invites Monkey to play. Their unexpected meeting becomes a new friendship."
        ],
        shortCaptions: [
            "Monkey walks through the jungle.",
            "He sees a tree full of bananas.",
            "He picks a banana and eats it.",
            "Monkey hears a noise behind the tree.",
            "A little elephant appears.",
            "Elephant’s ball is stuck in the branches.",
            "Monkey climbs the tree to help.",
            "Elephant catches the ball with his trunk.",
            "The new friends play together."
        ],
        extraDetails: [
            (page: 4, text: "Elephant has been trying to reach something above him."),
            (page: 5, text: "He cannot reach the ball, even when he stretches his trunk."),
            (page: 7, text: "Monkey waits until Elephant is ready before letting go.")
        ],
        questions: [
            q("Why does Monkey stop by the tree?", ["He sees ripe bananas.", "He is looking for a map.", "He hears someone calling."], 0, "Think about what Monkey finds before he eats."),
            q("What does Monkey do before eating?", ["He meets Elephant.", "He picks a banana.", "He climbs down a tree."], 1, "What happens on the page just before Monkey eats?"),
            q("Why does Elephant keep looking up?", ["He sees a bird flying.", "He wants to pick fruit.", "His ball is stuck above him."], 2, "Think about what Monkey sees in the branches."),
            q("What could Monkey do to help Elephant?", ["Find a safe way to reach the ball.", "Leave Elephant alone under the tree.", "Hide the ball behind the bananas."], 0, "What problem needs to be solved before they can play?"),
            q("How do Monkey and Elephant work together?", ["Elephant climbs while Monkey waits.", "Monkey reaches the ball and Elephant catches it.", "They both pull the tree down."], 1, "Remember what each friend does in the last three pages."),
            q("What has changed for Monkey by the end?", ["He has lost his way.", "He has found a new friend.", "He has run out of bananas."], 1, "Compare Monkey on the first page and on the last page.")
        ]
    )

    private static let journey = (
        captions: [
            "Monkey packs his red bag and sets off towards the west.",
            "Soon, a wide river cuts across the path. The water is too deep to walk through.",
            "A friendly Elephant offers to help. Together, they cross the river in a small boat.",
            "On the opposite bank, Monkey finds a fork in the path. He must choose which trail to follow.",
            "He follows the trail towards the west, then pauses beside a tall tree. He is unsure where to search next.",
            "Monkey remembers something in his red bag. Perhaps it can help him decide what to do.",
            "He unfolds an old treasure map. A small mark points to a spot beside a tree just like this one.",
            "Monkey kneels near the tree and begins to dig. Suddenly, his shovel strikes something hard beneath the soil.",
            "He uncovers a chest of old family treasure. The mark on the map led him to the right place."
        ],
        shortCaptions: [
            "Monkey packs his red bag.",
            "A wide river blocks his path.",
            "Elephant takes him across in a boat.",
            "The path splits in two.",
            "Monkey stops beside a tall tree.",
            "He opens his red bag.",
            "He takes out a treasure map.",
            "He digs near the tree.",
            "He finds a treasure chest."
        ],
        extraDetails: [
            (page: 3, text: "There are no footsteps to tell him which path is right."),
            (page: 5, text: "Instead of guessing, Monkey decides to look for a clue."),
            (page: 7, text: "He checks the mark on the map once more before digging deeper.")
        ],
        questions: [
            q("Why must Monkey stop at the river?", ["He wants to pick fruit.", "The water is too deep to cross on foot.", "He has forgotten his bag."], 1, "Think about what is blocking his journey."),
            q("How is Monkey able to continue his trip?", ["He crosses in Elephant’s boat.", "He jumps over the river.", "He follows the river back home."], 0, "Who helps Monkey on the third page?"),
            q("Why does Monkey have to make a choice?", ["His bag is empty.", "He is tired of walking.", "The path splits into two trails."], 2, "What does Monkey find after crossing the river?"),
            q("Why does Monkey open his bag?", ["He wants to share food.", "He remembers something that could guide him.", "He wants to put the tree inside."], 1, "Look at what Monkey takes out on the next page."),
            q("What makes Monkey dig beside the tree?", ["He notices a mark on the treasure map.", "Elephant tells him to dig anywhere.", "He loses his shovel in the grass."], 0, "Connect what Monkey sees on the map with the place where he stops."),
            q("What helped Monkey find the treasure?", ["He took the fastest trail without stopping.", "He matched a clue on the map to a place on the path.", "He waited for the treasure to appear."], 1, "Think about why looking carefully at the map mattered.")
        ]
    )

    private static let bird = (
        captions: [
            "Monkey hears a soft chirping sound while walking near the trees.",
            "He follows the sound and discovers a little bird sitting in a nest.",
            "The bird is keeping a single egg warm. It stays close to protect the egg.",
            "Suddenly, a few twigs slip from the edge of the nest and fall to the ground.",
            "Without those twigs, one side of the nest begins to lean. The egg moves closer to the edge.",
            "Monkey looks up and realizes that the egg could fall if the nest gets any weaker.",
            "He gathers sturdy twigs from the ground, choosing pieces that can support the nest.",
            "Monkey carefully reaches up and passes the twigs to the bird. Together, they strengthen the loose side.",
            "The nest is steady again, and the egg rests safely inside. The bird chirps as Monkey swings away with a smile."
        ],
        shortCaptions: [
            "Monkey hears a bird chirp.",
            "He sees a nest in a tree.",
            "A bird keeps an egg warm.",
            "Small twigs fall from the nest.",
            "The nest starts to lean.",
            "Monkey sees that the egg is not safe.",
            "Monkey collects strong twigs.",
            "Monkey and Bird fix the nest.",
            "The bird chirps. The egg is safe."
        ],
        extraDetails: [
            (page: 2, text: "Even when Monkey comes closer, the bird does not leave its egg."),
            (page: 4, text: "Each missing twig makes the weak side a little less stable."),
            (page: 7, text: "They place the strongest twigs under the loose edge so it cannot slip.")
        ],
        questions: [
            q("Why does Monkey look up at the tree?", ["He follows the sound of a bird.", "He sees a treasure chest.", "He wants to pick a banana."], 0, "What does Monkey hear before he finds the nest?"),
            q("Why does the bird stay close to its egg?", ["It wants to hide a map.", "It is keeping the egg warm and safe.", "It is waiting for Monkey to climb."], 1, "Think about what the bird does on the third page."),
            q("Why does the nest begin to lean?", ["The tree is moving away.", "The egg is getting bigger.", "Some of the twigs fall out."], 2, "What changes in the nest just before it leans?"),
            q("What might happen if the nest is not repaired?", ["The egg could fall.", "The tree would grow taller.", "The bird would find a ball."], 0, "Think about what is near the edge of the weak nest."),
            q("Why does Monkey choose strong twigs?", ["They can help support the nest.", "They are the prettiest colour.", "They make a louder sound."], 0, "What needs to become strong again?"),
            q("What makes the ending safe for the bird?", ["Monkey carries the egg away.", "Monkey and Bird repair the nest together.", "The bird leaves the nest behind."], 1, "Remember what the friends do before Monkey leaves.")
        ]
    )

    private static func q(_ text: String, _ options: [String], _ answer: Int, _ hint: String) -> StoryQuestion {
        StoryQuestion(text: text, options: options, answer: answer, hint: hint)
    }
}
