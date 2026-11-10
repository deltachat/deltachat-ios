import XCTest
@testable import DcCore

// Disable line length because it triggers when using "record steps"
// swiftlint:disable line_length

let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
let dc = XCUIApplication()
let transport = URL(string: "ci-chatmail.testrun.org")!

final class DcUITests: XCTestCase {

    override func setUpWithError() throws {
        localizationBundle = Bundle(for: type(of: self))
        continueAfterFailure = false
        DcAccounts.shared.sharedDbLocation = DcAccounts.simulatorDBLocation() ?? {
            // The simulatorDB can't be located if the app was never launched.
            dc.launch()
            return DcAccounts.simulatorDBLocation()
        }() ?? {
            XCTFail("Failed to find simulator database")
            return nil
        }()
    }

    override func tearDownWithError() throws {
        DcAccounts.shared.opened { $0.removeTestProfiles() }
    }

    @MainActor func testOnBoarding() throws {
        dc.launch()
        XCTAssert(dc.staticTexts[.localized("welcome_desktop")].waitForExistence(timeout: 3), """
            This test requires no accounts present on the simulator
        """)
        dc.buttons[.localized("onboarding_create_instant_account")].tap()
        dc.typeText("Onboarding Test")
        dc.buttons[.localized("instant_onboarding_create")].tap()
        XCTAssert(dc.staticTexts[.localized("pref_chats")].waitForExistence(timeout: 3))
        XCTAssert(dc.staticTexts[.localized("device_talk")].waitForExistence(timeout: 3))
        XCTAssert(dc.staticTexts[.localized("saved_messages")].waitForExistence(timeout: 3))
        XCTAssert(DcAccounts.shared.opened { $0.remove(id: $0.getSelected().id) })
    }

    @MainActor func testDeletingProfile() throws {
        let dcContext = DcAccounts.shared.opened {
            $0.selectNewProfile(online: false)
        }
        dc.launch()
        dc.buttons[.localized("switch_account")].tap()
        dc.staticTexts[dcContext.displayname!].press(forDuration: 1)
        dc.buttons[.localized("delete")].tap()
        springboard.typeText("1\n")
        dc.buttons[.localized("delete_account")].tap()
        XCTAssert(dc.staticTexts[dcContext.displayname!].waitForNonExistence(timeout: 3))
        XCTAssert(dc.staticTexts[.localized("welcome_desktop")].waitForExistence(timeout: 3))
    }

    @MainActor func testCompose() throws {
        let (contact, qr) = DcAccounts.shared.opened { dcAccounts in
            let contact = dcAccounts.selectNewProfile(online: true)
            dcAccounts.selectNewProfile(online: true)
            return (contact, contact.getSecurejoinQr(chatId: 0).flatMap(URL.init(string:)))
        }
        guard let qr else { return XCTFail("Failed to get secure join qr") }

        dc.open(qr)
        dc.buttons[.localized("ok")].tap()
        XCTAssert(dc.staticTexts[.localized("chat_protection_enabled_tap_to_learn_more")].waitForExistence(timeout: 3))
        XCTAssert(dc.textViews[.localized("write_message_desktop")].waitForExistence(timeout: 15))
        dc.textViews[.localized("write_message_desktop")].tap()
        dc.typeText("Hi")
        dc.buttons[.localized("menu_send")].tap()
        dc.backButton.tap()

        // Create group
        dc.buttons["Compose"].tap()
        dc.staticTexts[.localized("menu_new_group")].tap()
        dc.staticTexts[.localized("group_name") + ":"].tap()
        dc.typeText("Test Group")
        dc.staticTexts[.localized("chat_description")].tap()
        dc.typeText("Test Description")
        dc.staticTexts[.localized("group_add_members")].tap()
        dc.staticTexts[contact.displayname!].tap()
        dc.buttons["Done"].tap()
        dc.buttons[.localized("create")].tap()
        XCTAssert(dc.textViews[.localized("write_message_desktop")].waitForExistence(timeout: 3))
        dc.textViews[.localized("write_message_desktop")].tap()
        dc.typeText("Hi")
        dc.buttons[.localized("menu_send")].tap()
        // Check if compose vc is removed
        dc.backButton.tap()
        XCTAssert(dc.navigationBars[.localized("pref_chats")].waitForExistence(timeout: 1))
        // Check if group description was added
        dc.staticTexts["Test Group"].tap()
        dc.navigationBars.staticTexts["Test Group"].tap()
        XCTAssert(dc.buttons["Test Description"].exists)
        dc.backButton.tap()
        dc.backButton.tap()

        // Create Channel
        dc.buttons["Compose"].tap()
        dc.staticTexts[.localized("new_channel")].tap()
        dc.staticTexts[.localized("channel_name") + ":"].tap()
        dc.typeText("Test Channel")
        dc.staticTexts[.localized("chat_description")].tap()
        dc.typeText("Test Description")
        dc.buttons[.localized("create")].tap()
        XCTAssert(dc.textViews[.localized("write_message_desktop")].waitForExistence(timeout: 3))
        dc.textViews[.localized("write_message_desktop")].tap()
        dc.typeText("Hi")
        dc.buttons[.localized("menu_send")].tap()
        // Check if compose vc is removed
        dc.backButton.tap()
        XCTAssert(dc.navigationBars[.localized("pref_chats")].waitForExistence(timeout: 1))
        // Check if group description was added
        dc.staticTexts["Test Channel"].tap()
        dc.navigationBars.staticTexts["Test Channel"].tap()
        XCTAssert(dc.buttons["Test Description"].exists)
        dc.backButton.tap()
        dc.backButton.tap()
    }
}

// swiftlint:enable line_length


extension DcAccounts {
    func opened<T>(_ batch: (DcAccounts) -> T) -> T {
        dc.terminate()
        openDatabase(writeable: true)
        defer { closeDatabase() }
        return batch(self)
    }

    /// Find the accounts database that the simulator is using
    static func simulatorDBLocation() -> URL? {
        let sharedResources = ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"]
            .flatMap(URL.init(string:))!
            .appending(path: "Containers/Shared/AppGroup")
        return try? FileManager.default.contentsOfDirectory(at: sharedResources, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true }
            .first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("accounts").path) }
    }

    @discardableResult
    func selectNewProfile(online: Bool, caller: String = #function, line: Int = #line) -> DcContext {
        let name = caller + ":\(line)"
        let selected = getSelected()
        let newProfile = !selected.isConfigured() && selected.id != 0 ? selected : get(id: add())
        if online {
            XCTAssert(true == (try? newProfile.addTransportFromQr(qrCode: "dcaccount:\(transport)")))
            newProfile.setConfig("configured_addr", "ci-ios.test.\(name).\(Date().timeIntervalSince1970)@\(transport)")
        } else {
            newProfile.addPseudoTransport(addr: "ios.test.\(name)@delta.chat")
            newProfile.setConfig("configured_addr", "ci-ios.test.\(name)@delta.chat")
            newProfile.setConfigBool("bcc_self", false)
        }
        newProfile.setConfig("displayname", "\(name)")
        newProfile.setConfigBool("ui.ios.test_profile", true)
        XCTAssert(select(id: newProfile.id))
        return newProfile
    }

    func removeTestProfiles() {
        let profiles = getAll().compactMap(get(id:))
        for context in profiles where context.getConfigBool("ui.ios.test_profile") {
            _ = remove(id: context.id)
        }
    }
}

extension DcContext {
    public func addPseudoTransport(addr: String) {
        dc_add_pseudo_transport(contextPointer, addr)
    }
}

extension XCUIElementTypeQueryProvider {
    var backButton: XCUIElement {
        buttons["BackButton"]
    }
}
