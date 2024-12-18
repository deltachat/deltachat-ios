import XCTest
import SnapshotTesting

// TODO: Should create a test that generates screenshots for README and App Store
// TODO: Maybe split up the test into multiple tests

final class ChatTests: XCTestCase {
    var bundleIdentifier: String = "chat.delta.amzd"

    override func setUp() {
        continueAfterFailure = false
    }

    lazy var app = XCUIApplication(bundleIdentifier: bundleIdentifier)
    lazy var springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    func testChatViewController() {
        switch (UIDevice.current.systemVersion, UIDevice.current.name) {
        case ("16.4", "iPhone X"): break
        case ("17.5", "iPhone SE (3rd generation)"): break
        // Note: 18.1 changes the space bar to include locale which breaks
        // the screenshots if ran on a mac with a different locale.
        // So even if the keyboard is in English it will show "EN NL" on a mac with Dutch locale.
        case ("18.0", "iPhone 16"): break
        default: XCTFail("Not a tested device")
        }

        XCTAssertNotEqual(String.localized("write_message_desktop"), "write_message_desktop",
                          "Make sure localized strings work")

        app.resetAuthorizationStatus(for: .microphone)
        app.resetAuthorizationStatus(for: .camera)
        app.resetAuthorizationStatus(for: .photos)
        app.resetAuthorizationStatus(for: .contacts)

        // AppStateRestorer.Tab.chatTab = 12
        app.launchArguments += ["-last_active_tab2", "12"]
        app.launchArguments += ["-last_active_chat_id", "0"]
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launchArguments += ["-AppleLocale", "en_US"]
        app.launchArguments += ["--UITests"]
        app.launch()
        app.staticTexts[.localized("saved_messages")].tap()

        // There should be no messages. If this fails check why TestUtil.selectUITestAccount() did not
        // clear the self-chat.
        XCTAssert(app.staticTexts[.localized("saved_messages_explain")].waitForExistence(timeout: 2))

        // Send message
        app.textViews[.localized("write_message_desktop")].tap()
        XCTAssert(app.keyboards.firstMatch.exists)
        app.dismissKeyboardTutorialIfNeeded()
        app.textViews[.localized("write_message_desktop")].typeText("Hey!")
        app.buttons[.localized("menu_send")].tap()
        XCTAssert(app.cells[containing: .localized("a11y_delivery_status_delivered")].waitForExistence(timeout: 5))
        XCTAssert(app.keyboards.firstMatch.exists)
        screenshot(app, named: "Sent Message")

        // React with emoji
        app.cells[containing: "Hey!"].press(forDuration: 1)
        if #available(iOS 18.0, *) {
            // TODO: Figure out why iOS 18 can't find the button by localized string
            // maybe a localization issue that needs to be fixed in the app
            app.buttons["•••"].tap()
        } else {
            app.buttons[.localized("pref_other")].tap()
        }
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.staticTexts["😀"].firstMatch.tap()
        XCTAssert(app.keyboards.firstMatch.exists)
        screenshot(app, named: "Reacted with emoji")

        // Send Contact
        app.buttons[.localized("menu_add_attachment")].tap()
        app.buttons[.localized("contact")].tap()
        XCTAssert(app.navigationBars[.localized("contacts_title")].waitForExistence(timeout: 3))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        screenshot(app, named: "Selecting Contact")
        app.staticTexts[.localized("self")].tap()
        XCTAssert(app.keyboards.firstMatch.exists)
        // on iOS 16 the keyboard tutorial is shown the second time the keyboard is shown
        app.dismissKeyboardTutorialIfNeeded()
        screenshot(app, named: "Sending Contact")
        app.buttons[.localized("menu_send")].tap()
        screenshot(app, named: "Sent Contact")

        // Send audio message
        app.buttons[.localized("menu_add_attachment")].tap()
        app.buttons[.localized("voice_message")].tap()
        if springboard.staticTexts["“Delta Chat” Would Like to Access the Microphone"].exists {
            if #available(iOS 17, *) {
                springboard.buttons["Allow"].tap()
            } else {
                springboard.buttons["OK"].tap()
            }
        }
        sleep(3) // Wait for recording
        app.buttons[.localized("menu_send")].tap()
        XCTAssert(app.keyboards.firstMatch.exists)
        screenshot(app, named: "Sent Voice message")

        // Test Share Sheet
        app.cells[containing: .localized("voice_message")].press(forDuration: 1)
        // Note: The context menu here sometimes causes a long "waiting for idle" time
        app.buttons[.localized("menu_more_options")].tap()
        app.buttons[.localized("menu_more_options")].tap()
        app.buttons[.localized("menu_share")].tap()
        XCTAssert(app.textViews[.localized("write_message_desktop")].waitForNonExistence(timeout: 2))
        app.buttons[.localized("close")].tap()
        // keyboard is dismissed rn, but maybe it shouldn't be?
        XCTAssert(app.textViews[.localized("write_message_desktop")].waitForExistence(timeout: 2))

        // Check More Options menu and copy text
        app.cells[containing: "Hey!"].press(forDuration: 1)
        app.buttons[.localized("menu_more_options")].tap()
        app.buttons[.localized("menu_copy_text_to_clipboard")].tap()
        // keyboard is dismissed rn, but maybe it shouldn't be?
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.textViews[.localized("write_message_desktop")].press(forDuration: 2)
        app.menuItems["Paste"].tap()
        XCTAssertEqual(app.textViews[.localized("write_message_desktop")].value as? String, "Hey!")
        app.buttons[.localized("menu_send")].tap()

        // Test File Picker Search Field
        // Note: File Picker is broken in iOS 18 simulators using Rosetta
        if #unavailable(iOS 18) {
            app.buttons[.localized("menu_add_attachment")].tap()
            app.buttons[.localized("files")].tap()
            // Focus the search field in the picker to test if the first responder is returned after dismiss
            app.searchFields["Search"].tap()
            XCTAssert(app.keyboards.firstMatch.waitForExistence(timeout: 2))
            app.buttons["Cancel"].tap()
            XCTAssert(app.keyboards.firstMatch.exists)
            screenshot(app, named: "After File Picker")
        }

        // Send Photo
        // Note: Image Picker is broken in iOS 18 simulators using Rosetta
        // Note: Sadly simulators pre-iOS 18 do not have the search field so we should test this on a real device
        // wether the first responder is returned after using search field in the image picker.
        if #unavailable(iOS 18) {
            app.buttons[.localized("menu_add_attachment")].tap()
            app.buttons[.localized("gallery")].tap()
            if #available(iOS 17.0, *) {
                app.images["Photo, 30 March 2018, 21:14"].tap()
            } else {
                app.images["Photo, March 30, 2018, 21:14"].tap()
            }
            XCTAssert(app.keyboards.firstMatch.waitForExistence(timeout: 2))
            screenshot(app, named: "Selected Photo")
            app.buttons[.localized("menu_send")].tap()
            screenshot(app, named: "Sent Photo")
        }
    }

    override func tearDown() {
        // TODO: This is not working, the app is not terminated because of a bug with Rosetta simulators, but Rosetta is required for the snapshot dependency.... uhg
        // that means the app does not get terminated and does not clean up the test account
        // which is not that big of a deal because it is only on simulators but would like to fix it
        //        app.terminate()
    }

    // MARK: - Helpers

    /// The number of screenshots taken in this test. Used in the name of the screenshots to sort them chronologically.
    var numberOfScreenshots = 0
    lazy var navigationBarY = app.navigationBars.firstMatch.frame.minY
    lazy var bottomSafeAreaInset = app.frame.maxY - app.otherElements["safeAreaProvider"].frame.maxY

    func screenshot(
        _ app: XCUIApplication,
        named name: String,
        crop: Bool = true,
        record recording: Bool? = nil,
        timeout: TimeInterval = 5,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let previousContinueAfterFailure = continueAfterFailure
        continueAfterFailure = true

        // Wait for animations to finish
        sleep(1)

        // Crop out the status bar and the home indicator
        // Needed because the home indicator color is not deterministic and can change between runs (on iOS 18)
        // and the status bar can have different content depending on the state of the device (`xcrun simctl status_bar` does not work on rosetta simulators)
        let image: UIImage = crop ? {
            let cgImage = app.screenshot().image.cgImage!
            // Using navigationBarY instead of safeAreaProvider.minY because the safe area is
            // bigger than the navigation bar on iPhone 16 (iOS 18)
            let cropTopPercentage = navigationBarY / app.frame.height
            let cropTop = CGFloat(cgImage.height) * cropTopPercentage
            let cropBottomPercentage = bottomSafeAreaInset / app.frame.height
            let cropBottom = CGFloat(cgImage.height) * cropBottomPercentage
            let cropFrame = CGRect(x: 0.0, y: cropTop, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)-cropTop-cropBottom)
            let croppedCGImage = cgImage.cropping(to: cropFrame)!
            return UIImage(cgImage: croppedCGImage)
        }() : app.screenshot().image

        assertSnapshot(
            of: image,
            as: .image,
            named: "\(UIDevice.current.name) \(UIDevice.current.systemVersion) \(numberOfScreenshots) \(name)",
            record: recording,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
        numberOfScreenshots += 1
        continueAfterFailure = previousContinueAfterFailure
    }
}

extension XCUIApplication {
    /// Dissmisses the "swipe to type" keyboard tutorial if it is shown
    func dismissKeyboardTutorialIfNeeded() {
        let predicate = NSPredicate { (evaluatedObject, _) in
            (evaluatedObject as? XCUIElementAttributes)?.identifier == "UIContinuousPathIntroductionView"
        }
        let keyboardTutorialView = windows.otherElements.element(matching: predicate)
        if keyboardTutorialView.exists {
            keyboardTutorialView.buttons["Continue"].tap()
        }
    }
}

extension XCUIElementQuery {
    subscript(with part: String = "label", containing string: String) -> XCUIElement {
        precondition(!string.contains("'"))
        return self.element(matching: .init(format: "\(part) CONTAINS '\(string)'"))
    }
}
