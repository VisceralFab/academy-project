import XCTest

@MainActor
final class ReadLabUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCompleteJourneyAndResumeAllThreePaths() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-journey"]
        app.launch()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 15))
        capture("01-welcome", app: app)
        app.buttons["Get Started"].tap()
        let name = app.textFields["Child name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Luca\n")
        XCTAssertFalse(app.staticTexts["Reading familiarity · required"].exists)
        let age = app.buttons["ageRange-6–7"]
        age.tap()
        XCTAssertTrue(age.isSelected)
        capture("01b-profile", app: app)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["diagnosis-diagnosed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["dyslexicToggle"].exists)
        app.buttons["diagnosis-diagnosed"].tap()
        XCTAssertTrue(app.switches["dyslexicToggle"].waitForExistence(timeout: 5))
        app.switches["dyslexicToggle"].tap()
        capture("02-learning-preferences", app: app)
        app.switches["dyslexicToggle"].tap()
        app.buttons["diagnosis-none"].tap()
        XCTAssertFalse(app.switches["dyslexicToggle"].exists)
        app.buttons["Continue"].tap()
        let firstWords = app.buttons["readingPath-words"]
        XCTAssertTrue(firstWords.waitForExistence(timeout: 5))
        capture("03-reading-paths", app: app)
        for path in ["hearing", "words", "stories"] {
            XCTAssertTrue(app.buttons["mascot-\(path)"].exists)
            app.buttons["readingPath-\(path)"].tap()
            app.buttons["mascot-\(path)"].tap()
        }
        firstWords.tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Let’s Begin"].waitForExistence(timeout: 5))
        let lastSummary = app.buttons["summary-Reading path"]
        XCTAssertTrue(lastSummary.isHittable)
        XCTAssertLessThan(lastSummary.frame.maxY, app.buttons["Let’s Begin"].frame.minY)
        XCTAssertFalse(app.staticTexts["Reading familiarity"].exists)
        capture("04-summary", app: app)
        app.buttons["Let’s Begin"].tap()
        XCTAssertTrue(app.buttons["accountButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Jobs")).firstMatch.exists)
        XCTAssertTrue(app.buttons["mascotButton"].isHittable)
        app.buttons["mascotButton"].tap()
        capture("05-first-words-home", app: app)
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.sliders["Syllable focus"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["resumeSessionButton"].waitForExistence(timeout: 10))
        app.buttons["resumeSessionButton"].tap()
        XCTAssertTrue(app.staticTexts["1 of 6"].waitForExistence(timeout: 5))
        app.buttons["closeActivityButton"].tap()

        changePath("Hearing sounds", app: app)
        capture("07-hearing-home", app: app)
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.buttons["readingPrompt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["microphoneButton"].exists)
        capture("08-hearing-exercise", app: app)
        app.buttons["readingPrompt"].tap()
        confirmParagraphWithGrownUp(app: app)
        XCTAssertTrue(app.staticTexts["2 of 6"].waitForExistence(timeout: 5))
        app.buttons["closeActivityButton"].tap()

        changePath("Growing readers", app: app)
        XCTAssertTrue(app.staticTexts["Monkey’s Adventure"].exists)
        app.buttons["suggestAnotherTopicButton"].tap()
        XCTAssertTrue(app.staticTexts["Journey to the West"].exists)
        app.buttons["suggestAnotherTopicButton"].tap()
        XCTAssertTrue(app.staticTexts["Poor Little Bird"].exists)
        app.buttons["suggestAnotherTopicButton"].tap()
        capture("09-growing-readers-home", app: app)
        app.buttons["startMissionButton"].tap()
        XCTAssertTrue(app.staticTexts["Page 1 of 9"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["microphoneButton"].exists)
        XCTAssertFalse(app.sliders["Reading text size"].exists)
        XCTAssertTrue(app.buttons["storyParagraph0"].exists)
        XCTAssertFalse(app.buttons["storyParagraph1"].exists)
        capture("10-story", app: app)
        confirmParagraphWithGrownUp(app: app)
        XCTAssertTrue(app.staticTexts["Page 2 of 9"].waitForExistence(timeout: 6))
        app.buttons["closeActivityButton"].tap()
        app.buttons["resumeSessionButton"].tap()
        XCTAssertTrue(app.staticTexts["Page 2 of 9"].waitForExistence(timeout: 5))
        capture("10b-story-resume", app: app)
        for page in 3...9 {
            confirmParagraphWithGrownUp(app: app)
            XCTAssertTrue(app.staticTexts["Page \(page) of 9"].waitForExistence(timeout: 6))
        }
        confirmParagraphWithGrownUp(app: app)
        XCTAssertTrue(app.buttons["answerOption1"].waitForExistence(timeout: 6))
        capture("11-story-questions", app: app)
        app.buttons["answerOption1"].tap()
        app.buttons["Next Question"].tap()
        app.buttons["closeActivityButton"].tap()
        app.buttons["resumeSessionButton"].tap()
        XCTAssertTrue(app.staticTexts["What fruit did Monkey eat?"].waitForExistence(timeout: 5))
        app.buttons["answerOption2"].tap()
        app.buttons["Next Question"].tap()
        app.buttons["answerOption0"].tap()
        app.buttons["Finish Story"].tap()
        XCTAssertTrue(app.buttons["Back to Discoveries"].waitForExistence(timeout: 5))
        app.buttons["Back to Discoveries"].tap()
        XCUIDevice.shared.orientation = .portrait
        capture("12-growing-readers-portrait", app: app)
        changePath("First words", app: app)
        app.buttons["resumeSessionButton"].tap()
        XCTAssertTrue(app.staticTexts["1 of 6"].waitForExistence(timeout: 5))
        capture("13-first-words-portrait", app: app)
        app.buttons["closeActivityButton"].tap()
        changePath("Hearing sounds", app: app)
        app.buttons["resumeSessionButton"].tap()
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
        let resume = app.buttons["resumeSessionButton"]
        for _ in 0..<5 where !resume.isHittable { app.swipeUp() }
        resume.tap()
        XCTAssertTrue(app.buttons["closeActivityButton"].waitForExistence(timeout: 5))
        let prompt = app.buttons["readingPrompt"]
        for _ in 0..<5 where !prompt.isHittable { app.swipeUp() }
        XCTAssertTrue(prompt.isHittable)
        XCTAssertFalse(app.buttons["microphoneButton"].exists)
        capture("18-large-text-exercise", app: app)

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
