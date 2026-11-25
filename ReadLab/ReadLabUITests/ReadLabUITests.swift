import XCTest
import UIKit

@MainActor
final class ReadLabUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppStaysLandscapeWhenIPadRotates() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-journey"]
        app.launch()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 15))
        assertLandscape(app)
        for orientation: UIDeviceOrientation in [.landscapeLeft, .portraitUpsideDown, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            assertLandscape(app)
        }
        capture("landscape-locked-with-ipad-held-portrait", app: app)
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testTenPlusVocabularyFitsOnOneLineWithBothFonts() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-journey"]
        app.launch()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 15))
        app.buttons["Get Started"].tap()
        let name = app.textFields["Child name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Luca\n")
        app.buttons["ageRange-10+"].tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["diagnosis-none"].waitForExistence(timeout: 5))
        app.buttons["diagnosis-none"].tap()
        app.buttons["Continue"].tap()
        let hearing = app.buttons["readingPath-hearing"]
        XCTAssertTrue(hearing.waitForExistence(timeout: 5))
        hearing.tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Let’s Begin"].waitForExistence(timeout: 5))
        app.buttons["Let’s Begin"].tap()
        XCTAssertTrue(app.buttons["startMissionButton"].waitForExistence(timeout: 5))
        app.buttons["startMissionButton"].tap()
        let prompt = app.buttons["readingPrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.label, "Listen to astrophysics")
        app.buttons["closeActivityButton"].tap()
        changePath("First words", app: app)
        app.buttons["startMissionButton"].tap()
        assertSingleSyllableRow("paleontologist", app: app)
        capture("first-words-long-word-system", app: app)

        app.buttons["closeActivityButton"].tap()
        app.buttons["accountButton"].tap()
        let dyslexicFont = app.switches["Use OpenDyslexic Bold"]
        XCTAssertTrue(dyslexicFont.waitForExistence(timeout: 5))
        if !dyslexicFont.isHittable { app.swipeUp() }
        dyslexicFont.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let fontEnabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: dyslexicFont)
        XCTAssertEqual(XCTWaiter.wait(for: [fontEnabled], timeout: 5), .completed)
        app.buttons["Done"].tap()
        app.buttons["startMissionButton"].tap()
        assertSingleSyllableRow("paleontologist", app: app)
        capture("first-words-long-word-opendyslexic", app: app)
    }

    func testCompleteJourneyAndResumeAllThreePaths() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-journey"]
        app.launch()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["onboardingPrivacyCaption"].isHittable)
        capture("01-welcome", app: app)
        app.buttons["Get Started"].tap()
        let name = app.textFields["Child name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Luca\n")
        XCTAssertFalse(app.staticTexts["Reading familiarity · required"].exists)
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
        let age = app.buttons["ageRange-6–7"]
        age.tap()
        XCTAssertTrue(age.isSelected)
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        XCTAssertTrue(app.staticTexts["onboardingPrivacyCaption"].isHittable)
        capture("01b-profile", app: app)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["diagnosis-diagnosed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["dyslexicToggle"].exists)
        app.buttons["diagnosis-diagnosed"].tap()
        XCTAssertTrue(app.switches["dyslexicToggle"].waitForExistence(timeout: 5))
        app.switches["dyslexicToggle"].tap()
        XCTAssertTrue(app.staticTexts["onboardingPrivacyCaption"].isHittable)
        capture("02-learning-preferences", app: app)
        app.switches["dyslexicToggle"].tap()
        app.buttons["diagnosis-none"].tap()
        XCTAssertFalse(app.switches["dyslexicToggle"].exists)
        app.buttons["Continue"].tap()
        let firstWords = app.buttons["readingPath-words"]
        XCTAssertTrue(firstWords.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["onboardingPrivacyCaption"].isHittable)
        capture("03-reading-paths", app: app)
        for path in ["hearing", "words", "stories"] {
            let card = app.buttons["readingPath-\(path)"]
            XCTAssertTrue(card.isHittable)
            XCTAssertLessThan(card.frame.maxY, app.buttons["Continue"].frame.minY)
            card.tap()
            XCTAssertTrue(card.isSelected)
        }
        firstWords.tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Let’s Begin"].waitForExistence(timeout: 5))
        let lastSummary = app.buttons["summary-Reading path"]
        XCTAssertTrue(lastSummary.isHittable)
        XCTAssertLessThan(lastSummary.frame.maxY, app.buttons["Let’s Begin"].frame.minY)
        XCTAssertFalse(app.staticTexts["Reading familiarity"].exists)
        XCTAssertTrue(app.staticTexts["onboardingPrivacyCaption"].isHittable)
        capture("04-summary", app: app)
        app.buttons["Let’s Begin"].tap()
        XCTAssertTrue(app.buttons["accountButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["startMissionButton"].label.contains("Jobs"))
        XCTAssertTrue(app.buttons["mascotButton"].isHittable)
        app.buttons["mascotButton"].tap()
        let topicCard = app.buttons["startMissionButton"]
        XCTAssertEqual(topicCard.value as? String, "Level Medium, 0 of 6 words")
        capture("05-first-words-home", app: app)
        topicCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.83)).tap()
        XCTAssertTrue(app.sliders["Syllable focus"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["storyMascotSound"].exists)
        capture("06-first-words-exercise", app: app)
        XCTAssertFalse(app.buttons["Listen"].exists)
        // The syllable lens stays on screen while listening starts automatically.
        XCTAssertFalse(app.buttons["readingPrompt"].exists)
        XCTAssertFalse(app.buttons["microphoneButton"].exists)
        XCTAssertFalse(app.sliders["Reading text size"].exists)
        let focus = app.sliders["Syllable focus"].firstMatch
        let word = app.descendants(matching: .any)["readingPrompt"].firstMatch
        XCTAssertEqual(focus.frame.width, word.frame.width, accuracy: 3)
        XCTAssertLessThan(focus.frame.minY - word.frame.maxY, 20)
        focus.adjust(toNormalizedSliderPosition: 0.45)
        capture("06b-continuous-lens", app: app)
        focus.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(focus.frame.width, word.frame.width, accuracy: 3)
        XCTAssertTrue(app.staticTexts["1 of 6"].exists)
        app.buttons["closeActivityButton"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["startMissionButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["resumeSessionButton"].exists)
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.staticTexts["1 of 6"].waitForExistence(timeout: 5))
        app.buttons["closeActivityButton"].tap()

        changePath("Hearing sounds", app: app)
        capture("07-hearing-home", app: app)
        app.buttons["startMissionButton"].coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.35)).tap()
        XCTAssertTrue(app.buttons["readingPrompt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["microphoneButton"].exists)
        XCTAssertFalse(app.buttons["storyMascotSound"].exists)
        capture("08-hearing-exercise", app: app)
        app.buttons["readingPrompt"].tap()
        confirmParagraphWithGrownUp(app: app)
        XCTAssertTrue(app.staticTexts["2 of 6"].waitForExistence(timeout: 5))
        app.buttons["closeActivityButton"].tap()

        XCTAssertEqual(topicCard.value as? String, "Level Medium, 1 of 6 words")
        changePath("Growing readers", app: app)
        let storyTitle = app.staticTexts["Monkey’s Adventure"]
        let pageProgress = app.staticTexts["homeProgressCount"]
        XCTAssertTrue(storyTitle.exists)
        XCTAssertFalse(app.staticTexts["1 of 3"].exists)
        XCTAssertEqual(pageProgress.label, "0 of 9 pages")
        XCTAssertLessThan(storyTitle.frame.maxY, pageProgress.frame.minY)
        XCTAssertLessThan(pageProgress.frame.maxY, topicCard.frame.minY)
        app.buttons["suggestAnotherTopicButton"].tap()
        XCTAssertTrue(app.staticTexts["Journey to the West"].exists)
        app.buttons["suggestAnotherTopicButton"].tap()
        XCTAssertTrue(app.staticTexts["Poor Little Bird"].exists)
        app.buttons["suggestAnotherTopicButton"].tap()
        capture("09-growing-readers-home", app: app)
        XCTAssertEqual(app.scrollViews.count, 0)
        let storyCard = app.buttons["startMissionButton"]
        let initialCardFrame = storyCard.frame
        app.swipeUp()
        let cardStaysFixed = NSPredicate { _, _ in abs(storyCard.frame.minY - initialCardFrame.minY) < 1 }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: cardStaysFixed, object: storyCard)], timeout: 5), .completed)
        storyCard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.65)).tap()
        XCTAssertTrue(app.staticTexts["Page 1 of 9"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["microphoneButton"].exists)
        XCTAssertFalse(app.sliders["Reading text size"].exists)
        XCTAssertTrue(app.buttons["storyParagraph0"].exists)
        XCTAssertFalse(app.buttons["storyParagraph1"].exists)
        XCTAssertFalse(app.buttons["storyMascotSound"].exists)
        let storyMonkey = app.buttons["storyAnimal-monkey"]
        XCTAssertTrue(storyMonkey.isHittable)
        storyMonkey.tap()
        XCTAssertFalse(storyMonkey.isEnabled)
        XCTAssertEqual(storyMonkey.value as? String, "Taking a short pause")
        XCTAssertTrue(storyMonkey.wait(for: \.isEnabled, toEqual: true, timeout: 15))
        capture("10-story", app: app)
        confirmParagraphWithGrownUp(app: app)
        XCTAssertTrue(app.staticTexts["Page 2 of 9"].waitForExistence(timeout: 6))
        app.buttons["closeActivityButton"].tap()
        XCTAssertFalse(app.buttons["resumeSessionButton"].exists)
        XCTAssertEqual(app.staticTexts["homeProgressCount"].label, "1 of 9 pages")
        capture("10a-fixed-story-home-progress", app: app)
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.staticTexts["Page 2 of 9"].waitForExistence(timeout: 5))
        capture("10b-story-resume", app: app)
        for page in 3...9 {
            confirmParagraphWithGrownUp(app: app)
            XCTAssertTrue(app.staticTexts["Page \(page) of 9"].waitForExistence(timeout: 6))
            if page == 5 {
                let elephant = app.buttons["storyAnimal-elephant"]
                XCTAssertTrue(elephant.isHittable)
                elephant.tap()
                XCTAssertFalse(app.buttons["storyAnimal-monkey"].isEnabled)
                XCTAssertTrue(elephant.wait(for: \.isEnabled, toEqual: true, timeout: 15))
            }
        }
        confirmParagraphWithGrownUp(app: app)
        XCTAssertTrue(app.buttons["answerOption1"].waitForExistence(timeout: 6))
        capture("11-story-questions", app: app)
        app.buttons["answerOption1"].tap()
        tapEnabled("Next Question", app: app)
        app.buttons["closeActivityButton"].tap()
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.staticTexts["What fruit did Monkey eat?"].waitForExistence(timeout: 5))
        app.buttons["answerOption2"].tap()
        tapEnabled("Next Question", app: app)
        app.buttons["answerOption0"].tap()
        tapEnabled("Next Question", app: app)
        for (index, answer) in [1, 0, 2].enumerated() {
            app.buttons["answerOption\(answer)"].tap()
            tapEnabled(index == 2 ? "Finish Story" : "Next Question", app: app)
        }
        XCTAssertTrue(app.buttons["Back to Discoveries"].waitForExistence(timeout: 5))
        app.buttons["Back to Discoveries"].tap()
        XCUIDevice.shared.orientation = .portrait
        assertLandscape(app)
        capture("12-growing-readers-landscape-locked", app: app)
        app.buttons["suggestAnotherTopicButton"].tap()
        app.buttons["suggestAnotherTopicButton"].tap()
        XCTAssertTrue(app.staticTexts["Poor Little Bird"].exists)
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.staticTexts["Page 1 of 9"].waitForExistence(timeout: 5))
        confirmParagraphWithGrownUp(app: app)
        XCTAssertTrue(app.staticTexts["Page 2 of 9"].waitForExistence(timeout: 6))
        let bird = app.buttons["storyAnimal-bird"]
        XCTAssertTrue(bird.isHittable)
        bird.tap()
        XCTAssertFalse(app.buttons["storyAnimal-monkey"].isEnabled)
        capture("12b-bird-sound-pause-landscape-locked", app: app)
        XCTAssertTrue(bird.wait(for: \.isEnabled, toEqual: true, timeout: 15))
        confirmParagraphWithGrownUp(app: app)
        XCTAssertTrue(app.staticTexts["Page 3 of 9"].waitForExistence(timeout: 6))
        XCTAssertTrue(bird.isHittable)
        XCTAssertFalse(app.buttons["storyAnimal-monkey"].exists)
        app.buttons["closeActivityButton"].tap()
        // Restore the device orientation before testing vertical gestures in Settings.
        XCUIDevice.shared.orientation = .landscapeLeft
        changePath("First words", app: app)
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.staticTexts["1 of 6"].waitForExistence(timeout: 5))
        capture("13-first-words-landscape-locked", app: app)
        app.buttons["closeActivityButton"].tap()
        changePath("Hearing sounds", app: app)
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.staticTexts["2 of 6"].waitForExistence(timeout: 5))
        // A physical microphone is not available in automation. Verify the supported fallback flow.
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5))
        app.buttons["More"].tap()
        app.buttons["Practise with a Grown-up"].tap()
        app.buttons["A grown-up checked this reading"].tap()
        XCTAssertTrue(app.staticTexts["3 of 6"].waitForExistence(timeout: 5))
        capture("14-assisted-reading", app: app)
        app.buttons["closeActivityButton"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["accountButton"].waitForExistence(timeout: 5))
        capture("15-landscape-home", app: app)

        app.terminate()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["accountButton"].waitForExistence(timeout: 10))
        capture("16-large-text-home", app: app)
        app.buttons["accountButton"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        capture("17-large-text-account", app: app)
        app.buttons["Done"].tap()
        let activity = app.buttons["startMissionButton"]
        for _ in 0..<5 where !activity.isHittable { app.swipeUp() }
        activity.tap()
        XCTAssertTrue(app.buttons["closeActivityButton"].waitForExistence(timeout: 5))
        let prompt = app.buttons["readingPrompt"]
        for _ in 0..<5 where !prompt.isHittable { app.swipeUp() }
        XCTAssertTrue(prompt.isHittable)
        XCTAssertFalse(app.buttons["microphoneButton"].exists)
        capture("18-large-text-exercise", app: app)
        app.buttons["closeActivityButton"].tap()
        changePath("Growing readers", app: app)
        XCTAssertEqual(app.scrollViews.count, 0)
        XCTAssertTrue(app.buttons["startMissionButton"].isHittable)
        XCTAssertTrue(app.buttons["suggestAnotherTopicButton"].isHittable)
        XCTAssertTrue(app.staticTexts["homeProgressCount"].isHittable)
        XCTAssertFalse(app.buttons["resumeSessionButton"].exists)
        capture("19-large-text-fixed-story-home", app: app)

    }

    private func assertLandscape(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["appLayoutOrientation"].wait(for: \.label, toEqual: "landscape", timeout: 5),
                      "ReadLab must remain in landscape when the iPad rotates.")
    }

    private func tapEnabled(_ title: String, app: XCUIApplication) {
        let button = app.buttons[title]
        XCTAssertTrue(button.wait(for: \.isEnabled, toEqual: true, timeout: 5))
        button.tap()
    }

    private func assertSingleSyllableRow(_ expected: String, app: XCUIApplication) {
        let slider = app.sliders["Syllable focus"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let word = app.descendants(matching: .any)["readingPrompt"].firstMatch
        XCTAssertEqual(app.sliders.count, 1)
        XCTAssertEqual(word.label.filter(\.isLetter), expected)
        let track = slider.frame
        XCTAssertEqual(word.frame.midX, track.midX, accuracy: 8)
        for position in [0.5, 1] {
            slider.adjust(toNormalizedSliderPosition: position)
            XCTAssertEqual(slider.frame.width, track.width, accuracy: 1)
            XCTAssertEqual(word.label.filter(\.isLetter), expected)
        }
    }

    private func confirmParagraphWithGrownUp(app: XCUIApplication) {
        app.buttons["More"].tap()
        app.buttons["Practise with a Grown-up"].tap()
        app.buttons["A grown-up checked this reading"].tap()
    }

    private func changePath(_ title: String, app: XCUIApplication) {
        app.buttons["accountButton"].tap()
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
        app.buttons[title].tap()
        if title == "Hearing sounds" {
            for _ in 0..<3 {
                if app.switches["Background music"].exists { break }
                app.swipeUp()
            }
            capture("account-audio-and-report", app: app)
            XCTAssertTrue(app.switches["Background music"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.switches["Animal sounds"].exists)
            XCTAssertFalse(app.buttons["Reading familiarity"].exists)
        }
        capture("account-\(title)", app: app)
        app.buttons["Done"].tap()
    }
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
