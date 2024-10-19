//
//  deltachat_ios_uitestsLaunchTests.swift
//  deltachat-ios-uitests
//
//  Created by Casper Zandbergen on 13/10/2024.
//  Copyright © 2024 merlinux GmbH. All rights reserved.
//

import XCTest
import SnapshotTesting
@testable import deltachat_ios

final class ChatTests: XCTestCase {
    var bundleIdentifier: String = "chat.delta.amzd"

    override func setUp() {
        continueAfterFailure = false
    }

    func testCreateAccount() throws {
//        let url = URL(string: "chat.delta.deeplink://?chatId=1")!
//        let url = URL(string: "dcaccount://https://nine.testrun.org/new")!
        let app = XCUIApplication(bundleIdentifier: bundleIdentifier)
//        app.open(url)
        app.launchArguments += ["-last_active_tab2", "12"]
        app.launchArguments += ["-last_active_chat_id", "0"]
        app.launchArguments += ["--UITests"]
        app.launch()
        // TODO: get localizable strings from app
//        XCTAssertFalse(app.navigationBars["Welcome to Delta Chat"].exists)
        app.buttons["Create New Profile"].tap()
        app.textFields["Your Name"].tap()
        app.textFields["Your Name"].typeText("UITest")

        
        app.buttons["Agree & Create Profile"].tap()
        let notificationsAlert = app.alerts["“Delta Chat” Would Like to Send You Notifications"]
        if notificationsAlert.exists {
            notificationsAlert.buttons["Allow"].tap()
        }

        screenshot(app, named: "Created Account")
    }

    /// Make sure an account is logged in eg through testCreateAccount()
    /// Warning: This clears your saved messages
    func testChatViewController() {
        let app = XCUIApplication(bundleIdentifier: bundleIdentifier)

        // AppStateRestorer.Tab.chatTab = 12
        app.launchArguments += ["-last_active_tab2", "12"]
        app.launchArguments += ["-last_active_chat_id", "0"]
        app.launchArguments += ["--UITests"]
        app.launch()
        app.staticTexts["Saved Messages"].tap()

        // Clear Saved Messages
        app.buttons["View Profile"].tap()
        app.staticTexts["Clear Chat"].tap()
        if app.buttons["Clear Chat"].exists {
            app.buttons["Clear Chat"].tap()
        } else { // chat was already empty
            app.navigationBars.buttons["Chat"].tap()
        }

        // Send message
        app.textViews["Write a message"].tap()
        app.textViews["Write a message"].typeText("Hey!")
        app.buttons["Send"].tap()
        XCTAssert(app.cells[containing: "Delivery status: Delivered"].waitForExistence(timeout: 5))
        screenshot(app, named: "Sent Message")

        // Send Contact
        app.buttons["Add Attachment"].tap()
        app.buttons["Contact"].tap()
        XCTAssert(app.navigationBars["Contacts"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        screenshot(app, named: "Selecting Contact")
        app.staticTexts["Me"].tap()
        XCTAssert(app.keyboards.firstMatch.exists)
        screenshot(app, named: "Sending Contact")
        app.buttons["Send"].tap()
        screenshot(app, named: "Sent Contact")

        app.buttons["Add Attachment"].tap()
        app.buttons["Voice Message"].tap()
        let notificationsAlert = app.alerts["“Delta Chat” Would Like to Access the Microphone"]
        if notificationsAlert.exists {
            notificationsAlert.buttons["Allow"].tap()
        }
        XCTAssert(app.navigationBars["00:03"].waitForExistence(timeout: 5))
        app.buttons["Send"].tap()
        screenshot(app, named: "Sent Voice message")

        // TODO: Make current date cell say "Today" so this test works tomorrow too
    }
}

extension XCTestCase {
    func screenshot(
        _ app: XCUIApplication,
        named name: String,
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
        assertSnapshot(
            of: app.screenshot().image,
            as: .image,
            named: name + " - \(UIDevice.current.name) (\(UIDevice.current.systemVersion))",
            record: recording,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
        continueAfterFailure = previousContinueAfterFailure
    }
}

extension XCUIElementQuery {
    subscript(with part: String = "label", containing string: String) -> XCUIElement {
        precondition(!string.contains("'"))
        return self.element(matching: .init(format: "\(part) CONTAINS '\(string)'"))
    }
}
