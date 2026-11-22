import Foundation

/// New editions share the original nine illustrations and keep their quiz tied to the text.
enum ReadLabAgeStoryContent {
    private typealias Edition = (pages: [String], questions: [StoryQuestion])

    static func story(for theme: ReadingTheme, age: ReadLabAgeRange) -> ReadingStory? {
        let edition: Edition
        switch theme.id {
        case "monkey-adventure": edition = monkey(age)
        case "journey-to-west": edition = journey(age)
        case "poor-little-bird": edition = bird(age)
        default: return nil
        }
        return ReadingStory(title: theme.title, sections: [edition.pages], questions: edition.questions)
    }

    private static func monkey(_ age: ReadLabAgeRange) -> Edition {
        switch age {
        case .fourFive:
            ([
                "Monkey walks through the jungle.",
                "He sees a tree full of bananas.",
                "He picks a banana and eats it.",
                "Monkey hears a noise behind the tree.",
                "A little elephant steps out.",
                "His ball is stuck in the tree.",
                "Monkey climbs to get the ball.",
                "Elephant catches it with his trunk.",
                "The new friends play together."
            ], [
                q("Where does Monkey walk?", ["In a garden", "In the jungle", "In a park"], 1, "Read the first page."),
                q("What does Monkey eat?", ["An apple", "A pear", "A banana"], 2, "Look at the fruit on the tree."),
                q("Who steps out after the noise?", ["Elephant", "Bird", "Monkey"], 0, "Think of the animal with a trunk."),
                q("What is stuck in the tree?", ["A banana", "A ball", "A bag"], 1, "What does Monkey go up to get?"),
                q("What does Elephant catch the ball with?", ["His feet", "His ears", "His trunk"], 2, "Look at Elephant on page eight."),
                q("What do the friends do at the end?", ["Play", "Eat", "Sleep"], 0, "Look at the last page.")
            ])
        case .sixSeven:
            ([
                "Monkey walks along a quiet path through the jungle.",
                "He stops when he sees bright yellow bananas in a tree.",
                "Monkey is hungry after his walk. He picks a banana and eats it.",
                "Just as he finishes eating, Monkey hears a rustle behind the tree.",
                "A little elephant steps out. He keeps looking up at the branches.",
                "Elephant cannot reach his ball because it is stuck high in the tree.",
                "Monkey wants to help, so he climbs the tree to reach the ball.",
                "Monkey lets the ball go, and Elephant catches it with his trunk.",
                "With the ball back, Elephant and Monkey spend the afternoon playing together."
            ], [
                q("Where does the story take place?", ["Forest", "Jungle", "Park"], 1, "Read the first page."),
                q("What fruit did Monkey eat?", ["Apple", "Melon", "Banana"], 2, "Think of the bright yellow fruit."),
                q("Which animal did Monkey meet?", ["Elephant", "Monkey", "Iguana"], 0, "Think of the animal looking up."),
                q("Why can’t Elephant reach his ball?", ["It rolled down the path.", "It is high in the tree.", "It is behind the trunk."], 1, "Where is the ball on page six?"),
                q("Why does Monkey climb the tree?", ["To get the ball", "To pick more bananas", "To look for the noise"], 0, "What does Elephant need?"),
                q("What do the friends do once the ball is back?", ["Look for another tree", "Go for a walk", "Play together"], 2, "Read the last page.")
            ])
        case .eightNine:
            ([
                "Monkey follows a quiet jungle path. He makes his way past the reeds and along the water.",
                "A flash of yellow catches his eye. He stops beneath a tree with ripe bananas tucked among its leaves.",
                "The long walk has made Monkey hungry, so he picks a ripe banana and eats it beside the tree.",
                "Just as he finishes eating, leaves rustle behind the tree. Monkey pauses to see where the noise came from.",
                "A little elephant steps out from behind the tree. His worried eyes keep returning to the branches above him.",
                "Monkey follows Elephant’s gaze and spots a ball wedged among the branches. The ball is too high for Elephant to reach.",
                "Monkey can climb where Elephant cannot reach, so he grips the trunk and makes his way towards the ball.",
                "Monkey gently releases the ball from a branch. Elephant is ready below and catches it with his trunk.",
                "With the ball safely back, the two spend the afternoon playing under the tree. The worried elephant has found a friend."
            ], [
                q("Why does Monkey stop on his walk?", ["He spots ripe fruit.", "He hears the rustle.", "He sees Elephant."], 0, "The first reason to stop comes before the noise."),
                q("What does the rustle make Monkey do?", ["Climb to the bananas", "Pause and look for its source", "Follow the path again"], 1, "Focus on what happens just after he eats."),
                q("How does Monkey figure out what worries Elephant?", ["He looks behind the tree.", "He checks the path for tracks.", "He looks where Elephant is looking."], 2, "Where are Elephant’s eyes turned?"),
                q("Why is Monkey able to help?", ["He can climb to a spot Elephant cannot reach.", "He knows the path better than Elephant.", "He has already found fruit on the tree."], 0, "The problem is the height of the ball."),
                q("Why is Elephant ready below the tree?", ["To see where the rustle came from", "To catch the ball when it drops", "To fetch another banana"], 1, "Connect what each friend does on page eight."),
                q("How does Elephant change from the middle to the end?", ["He goes from curious to lost.", "He goes from hungry to full.", "He goes from worried to playing with a friend."], 2, "Compare the lost ball with the last page.")
            ])
        case .tenPlus:
            ([
                "Monkey follows a quiet trail into the jungle, with reeds along the water and mist between the hills. For now, his walk is a solitary one.",
                "A patch of yellow catches his attention among the leaves. The bright clusters belong to a banana tree, and Monkey stops to take a closer look.",
                "The walk has left Monkey hungry, and there is ripe fruit within reach. He picks a banana and eats it beneath the tree.",
                "Just as the last bite disappears, a sudden rustle breaks the quiet behind the tree. Monkey pauses and turns towards the sound to find out what caused it.",
                "A little elephant emerges from behind the trunk. He looks worried, and his gaze keeps wandering back up to a spot among the branches.",
                "Following Elephant’s gaze, Monkey discovers a ball wedged high in the tree. It is clear why Elephant is worried: even his long trunk cannot reach it.",
                "Monkey realizes that he can approach the ball from above, while Elephant can wait safely on the ground. Using the trunk and branches, Monkey climbs carefully.",
                "From the branch, Monkey frees the ball and lets it drop gently. Elephant is ready to catch it with his trunk, so the ball never hits the ground.",
                "Once the ball is safely returned, there is no reason for the two to part right away. They spend the afternoon playing beneath the tree, and a brief encounter becomes a friendship."
            ], [
                q("Why is the opening walk described as solitary?", ["To contrast it with the company Monkey finds later", "To suggest Monkey wants the jungle to himself", "To explain why Elephant cannot find the tree"], 0, "Compare the company Monkey has at the start and at the end."),
                q("What shifts Monkey’s attention away from his own needs?", ["Finding another bunch of fruit", "Hearing a rustle that leads to Elephant", "Reaching the end of the path"], 1, "The story changes direction when Monkey finishes eating."),
                q("What clue lets Monkey infer Elephant’s problem?", ["Elephant stands in the shade.", "Elephant watches the path.", "Elephant keeps looking up at the same spot."], 2, "Follow the direction of Elephant’s gaze."),
                q("What is the strongest reason for Monkey’s plan?", ["It uses Monkey’s climbing and Elephant’s ability to catch.", "It lets both friends climb to the same branch.", "It gives Elephant another chance to reach from the ground."], 0, "Think about what each character can do from a different position."),
                q("What might happen if Monkey released the ball before Elephant was ready?", ["It would be easier to catch.", "It might hit the ground or roll away.", "It might stay in the same spot."], 1, "Why does Elephant wait below the branch?"),
                q("Which idea is best supported by the ending?", ["Careful plans are useful only when you work alone.", "Finding something to eat is the main purpose of a walk.", "Helping someone can turn a chance meeting into a friendship."], 2, "What remains after Elephant gets his ball back?")
            ])
        }
    }

    private static func journey(_ age: ReadLabAgeRange) -> Edition {
        switch age {
        case .fourFive:
            ([
                "Monkey packs his red bag.",
                "A wide river blocks the path.",
                "Elephant takes Monkey across in a boat.",
                "The path splits in two.",
                "Monkey stops beside a tree.",
                "He looks inside his red bag.",
                "He takes out a treasure map.",
                "He digs near the tree.",
                "He finds a treasure chest."
            ], [
                q("What colour is Monkey’s bag?", ["Blue", "Green", "Red"], 2, "Look at the bag on page one."),
                q("How do they cross the river?", ["In a boat", "On a bridge", "Over stones"], 0, "Think of what carries them on the water."),
                q("How many paths does Monkey see?", ["One", "Two", "Three"], 1, "The path splits."),
                q("Where does Monkey look for his map?", ["In his bag", "In the boat", "Under the tree"], 0, "Think of what he packed."),
                q("Where does Monkey dig?", ["By the river", "Near the tree", "On the first path"], 1, "Where does he stop to look at the map?"),
                q("What does Monkey find?", ["A small bag", "A folded map", "A treasure chest"], 2, "Look at the last page.")
            ])
        case .sixSeven:
            ([
                "Monkey packs his red bag and sets off towards the west.",
                "A wide river blocks the path. It is too deep to cross on foot.",
                "Elephant offers to help, and they cross the river in a small boat.",
                "On the other bank, the path splits in two. Monkey must choose a trail.",
                "Monkey follows the west trail and stops by a tree to look around.",
                "He remembers something in his red bag that might help him find his way.",
                "Monkey takes out a treasure map. A mark on it shows a spot by a tree.",
                "Monkey digs near the tree. His shovel hits something hard under the soil.",
                "Monkey uncovers a chest of family treasure. The mark on the map was right."
            ], [
                q("Which way does Monkey set off?", ["North", "West", "East"], 1, "Read the first page."),
                q("Why does Monkey need Elephant’s boat?", ["The river is too deep to walk through.", "He needs to carry the chest.", "He wants to return home."], 0, "What blocks the route?"),
                q("What does Monkey find on the other bank?", ["A chest", "Another boat", "Two trails"], 2, "Think about why he has to choose a way."),
                q("What does Monkey take out of his bag to help him?", ["A shovel", "A map", "A snack"], 1, "Find what has a mark by a tree."),
                q("Why does Monkey dig near the tree?", ["The map marks that spot.", "He dropped his bag there.", "Elephant stopped there to wait."], 0, "Connect the mark on the map with where he is."),
                q("What tells Monkey that the map was right?", ["The path keeps going west.", "The river gets narrower.", "He finds his family’s treasure."], 2, "Read the last page.")
            ])
        case .eightNine:
            ([
                "Monkey packs his red bag and turns west. He follows the sign, ready to see what is waiting along the trail.",
                "Soon a broad river cuts across the trail. The water is too deep to wade through, so Monkey stops on the bank.",
                "Elephant notices Monkey waiting by the water and offers a ride. The two cross safely in a small boat.",
                "On the opposite bank, a fork in the trail leaves Monkey with two choices. He must decide which way to go.",
                "Monkey follows the trail towards the west and pauses beside a tree. He cannot tell where he should look next.",
                "Instead of searching at random, Monkey remembers an item in his red bag. It might help him work out where to dig.",
                "Monkey unfolds his treasure map and studies a small mark beside a tree. It matches the place where he stopped.",
                "Monkey begins to dig beside the tree shown on the map. After a few shovelfuls, he strikes something solid beneath the soil.",
                "An old chest emerges from the soil. Inside is his family’s treasure, hidden at the spot that the map marked beside the tree."
            ], [
                q("Why does Monkey stop at the bank?", ["He needs to rest.", "He sees an unfamiliar trail.", "The river is too deep to cross on foot."], 2, "Think of what would happen if he tried to walk across."),
                q("How does Elephant change what Monkey can do next?", ["His boat lets Monkey reach the opposite trail.", "He points out a place to dig.", "He shows Monkey where to find a map."], 0, "Monkey needs to get to the other side."),
                q("Why does Monkey have to make a decision after crossing?", ["He has to find the boat again.", "He finds two possible trails.", "He has lost the red bag."], 1, "What does a fork mean for someone following a route?"),
                q("Why does Monkey look in his bag by the tree?", ["He is getting ready to go home.", "He is looking for something to eat.", "He remembers he has something that can guide him."], 2, "What does he unfold on the next page?"),
                q("What convinces Monkey to dig in this particular spot?", ["The mark on the map matches the tree beside him.", "He can see the lid above the soil.", "The soil looks easier to dig."], 0, "Connect the detail on the map to the place on the trail."),
                q("How does Monkey know his search succeeded?", ["He can see the river from the tree.", "He uncovers the family treasure.", "He finds the path he followed."], 1, "Think of what he was hoping to find.")
            ])
        case .tenPlus:
            ([
                "Monkey packs his red bag and sets off along the trail marked west. The sign gives him a direction, but it does not tell him what he will find on the way.",
                "A wide river interrupts the trail, and the water is too deep for Monkey to wade through. Continuing safely means finding a way to cross without stepping into the current.",
                "Elephant offers to carry Monkey across in a small boat. By accepting the ride, Monkey gets around an obstacle that has nothing to do with which trail he chose.",
                "The river is behind him, but the path on the opposite bank divides in two. Monkey must make another decision before his trip can continue.",
                "Monkey chooses the west trail and stops beside a tree. He knows the direction he has been following, but that alone does not tell him which spot to search.",
                "He considers looking around the tree and along the trail, then remembers what he packed in his red bag. It might help him narrow the search before he starts digging.",
                "He unfolds an old treasure map, noticing a small mark beside the drawing of a tree. The place where he is standing matches the clue.",
                "Monkey digs beside the tree rather than trying several spots along the path. The shovel strikes something hard beneath the soil, so he clears the dirt around it.",
                "The hard surface is the lid of a chest holding his family’s old treasure. Reaching it took both help getting across the river and a careful choice of where to dig."
            ], [
                q("Why is following the west sign alone insufficient?", ["It points back to the river.", "It indicates direction, but leaves later obstacles and choices unresolved.", "It marks the precise spot beneath the tree."], 1, "Think about what the sign tells Monkey and what he still has to work out."),
                q("What would likely happen without Elephant’s help?", ["Monkey could follow the same trail straight across.", "Monkey would know where his family hid the chest.", "Monkey would need another safe way to cross."], 2, "The depth of the river is the problem here."),
                q("Why are crossing the river and choosing a trail different problems?", ["One needs safe transport, while the other needs a decision about direction.", "One needs a map while the other needs a shovel.", "Both can be solved by following the boat."], 0, "Think about what changes after Monkey steps onto the far bank."),
                q("What does remembering the map change about Monkey’s approach?", ["He can choose a spot based on a clue instead of guessing.", "He can dig faster in every spot along the trail.", "He can tell exactly how deep the river is."], 0, "Compare searching widely with using something that narrows the search."),
                q("What makes the mark on the map useful?", ["It shows what is inside the chest.", "It tells him how deep to dig.", "It matches a feature Monkey can see on the trail."], 2, "A mark is most helpful when it points to something he can recognize."),
                q("Which statement best explains Monkey’s success?", ["He reaches the spot by trusting luck alone.", "He accepts help with one obstacle and uses evidence for the next.", "He keeps going without changing his plans."], 1, "Think about both Elephant’s role and how Monkey used the map.")
            ])
        }
    }

    private static func bird(_ age: ReadLabAgeRange) -> Edition {
        switch age {
        case .fourFive:
            ([
                "Monkey hears a little bird.",
                "He sees a nest in a tree.",
                "Bird keeps an egg warm.",
                "Small twigs fall from the nest.",
                "The nest starts to lean.",
                "The egg might fall.",
                "Monkey picks up strong twigs.",
                "Monkey and Bird fix the nest.",
                "Bird chirps beside the safe egg."
            ], [
                q("What does Monkey hear?", ["Bird", "Elephant", "Wind"], 0, "Listen for the sound on page one."),
                q("What is Bird keeping warm?", ["A leaf", "An egg", "A twig"], 1, "Look inside the nest."),
                q("What falls from the nest?", ["An egg", "Leaves", "Twigs"], 2, "Think of what the nest is made of."),
                q("What might fall when the nest leans?", ["The egg", "A banana", "The tree"], 0, "What is inside the nest?"),
                q("What does Monkey pick up?", ["Soft leaves", "Strong twigs", "Round stones"], 1, "Think of what will hold the nest up."),
                q("How is the nest at the end?", ["Still leaning", "Empty", "Safe again"], 2, "What changes after Monkey and Bird fix it?")
            ])
        case .sixSeven:
            ([
                "Monkey hears a little bird chirp while he walks near the trees.",
                "He follows the chirp and finds Bird in a nest high in a tree.",
                "Bird sits close to a single egg to keep it warm.",
                "A few twigs slip out of the nest and fall to the ground.",
                "The nest starts to lean to one side. The egg moves towards the edge.",
                "Monkey sees that the egg might fall if the nest gets weaker.",
                "He picks up strong twigs from the ground to help hold the nest up.",
                "Monkey passes the twigs to Bird. Together, they fix the weak side.",
                "The egg is safe again. Bird chirps happily in the nest."
            ], [
                q("How does Monkey find Bird?", ["He follows the chirp.", "He follows tracks.", "He looks for a banana."], 0, "What does he hear first?"),
                q("Why does Bird sit close to the egg?", ["To hide it from Monkey", "To keep it warm", "To move it to another nest"], 1, "Read the third page."),
                q("What starts the trouble with the nest?", ["It fills with leaves.", "The tree shifts.", "Some twigs slip out."], 2, "What happens just before the nest leans?"),
                q("Why does Monkey want to help?", ["The egg might fall.", "He wants to move closer to it.", "He wants to make his own nest."], 0, "Look at the position of the egg."),
                q("What do Monkey and Bird fix?", ["The trunk of the tree", "The weak side of the nest", "The ground under the tree"], 1, "Where do they use the twigs?"),
                q("What happens once the nest is safe?", ["Bird moves to another branch.", "Monkey takes the egg with him.", "Bird chirps happily."], 2, "Read the last page.")
            ])
        case .eightNine:
            ([
                "Monkey hears a soft chirp as he walks near the trees. He turns towards the sound to see where it comes from.",
                "Monkey follows the sound and finds a little bird sitting in a nest high in a tree. From below, he can see it is guarding something.",
                "Bird is keeping a single egg warm inside the nest. It stays close so the egg is protected while Monkey watches.",
                "A few twigs slide out of the nest and tumble to the ground. The spot they came from looks thinner than the rest.",
                "Without the missing twigs, one side of the nest starts to sag. As it tilts, the egg shifts closer to the edge.",
                "Monkey realizes that the egg could fall if the nest gets any weaker. The loose side needs support before the egg slips.",
                "Monkey gathers sturdy twigs from the ground. He picks the strongest ones because they need to support the loose side.",
                "He reaches up and passes the twigs to Bird. They work together to fill the gap and strengthen the weak edge.",
                "The nest is steady again, and the egg rests safely inside. Bird chirps happily now that the danger has passed."
            ], [
                q("What makes Monkey turn towards the tree?", ["He spots an egg.", "He hears a quiet chirp.", "He sees twigs on the ground."], 1, "The sound comes before Monkey sees the nest."),
                q("What tells Monkey that Bird has a reason to stay in the nest?", ["Bird sits close to an egg to protect it.", "Bird is about to find more twigs.", "Bird watches Monkey near the ground."], 0, "Look at what Bird is keeping warm."),
                q("How do the missing twigs affect the egg?", ["They make the egg roll to the middle.", "They make Bird carry the egg.", "They let the nest sag, so the egg moves towards the edge."], 2, "Connect the loss of support with where the egg moves."),
                q("Why does the loose side need fixing soon?", ["The egg could slip out if the nest gets weaker.", "The twigs might become harder to see.", "Bird will need more room beside the egg."], 0, "What risk does Monkey notice on page six?"),
                q("Why does Monkey choose sturdy twigs?", ["They are warmer than leaves.", "They can hold up the loose part of the nest.", "They match the tree’s colour."], 1, "Think about what support means here."),
                q("What shows that the repair worked?", ["Bird stops guarding the egg.", "Monkey finds a new tree.", "The nest stays steady with the egg safely inside."], 2, "Compare the condition of the nest before and after the repair.")
            ])
        case .tenPlus:
            ([
                "Monkey hears a soft chirping sound while walking near the trees. Curious about its source, he turns his attention away from the path.",
                "Following the chirp, he spots a small bird perched in a nest among the leaves. Monkey watches from below and notices that the bird is staying close to something.",
                "A single egg lies in the nest. Bird remains beside it to protect it and keep it warm, even with Monkey watching from the ground.",
                "A few twigs slip from one edge of the nest and drop to the ground. The change is small, but it leaves one part of the nest thinner and less supported.",
                "The side with fewer twigs begins to sag under the weight it carries. As the nest tilts, the egg shifts towards that edge instead of resting securely in the middle.",
                "Monkey realizes that the egg could fall if the edge leans any farther. To keep Bird and the egg together, he needs to help the nest support their weight again.",
                "Monkey gathers sturdy twigs from the ground, choosing pieces that are unlikely to bend. The new twigs can reinforce the part of the nest that has lost its support.",
                "Monkey reaches up and passes the twigs to Bird. Together, they fill the loose edge and strengthen it enough to hold the nest steady.",
                "With the nest stable again, the egg rests safely inside and Bird chirps happily. Monkey can leave because the repair will keep helping even after he is gone."
            ], [
                q("What leads Monkey from the path to noticing the bird's situation?", ["The sound prompts him to look more closely.", "The falling egg lands near him.", "The nest already blocks the path."], 0, "Separate what initially draws his attention from the later problem."),
                q("Why does it matter that Bird stays close to the egg?", ["It tells Monkey where to collect twigs.", "It helps explain why repairing the nest is better than asking Bird to leave.", "It shows Bird has finished building the nest."], 1, "Consider what Bird is trying to protect."),
                q("Which chain of events best explains the danger?", ["The chirp frightens Monkey, and the branches shake.", "The egg shifts first, pulling twigs down with it.", "Twigs fall, the edge loses support, and the egg slides towards it."], 2, "Order the changes in the nest across pages four and five."),
                q("What is a likely consequence of using twigs that bend easily?", ["The repaired side could sag again under the weight.", "The egg would stay in the middle more easily.", "Bird would have less room to chirp."], 0, "Think about why Monkey selects sturdier pieces."),
                q("Why do the two work on the loose edge specifically?", ["It is the easiest place to see from below.", "Restoring support there addresses the cause of the tilt.", "They want to make the nest larger all around."], 1, "Look back at what changed when twigs first fell."),
                q("Which idea does the ending best illustrate?", ["It is enough to notice when something goes wrong.", "A problem is solved only while someone watches it.", "Helping can mean fixing the cause so the solution lasts."], 2, "Why can Monkey safely leave at the end?")
            ])
        }
    }

    private static func q(_ text: String, _ options: [String], _ answer: Int, _ hint: String) -> StoryQuestion {
        StoryQuestion(text: text, options: options, answer: answer, hint: hint)
    }
}
