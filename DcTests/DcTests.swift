import Testing
import XCTest
import DcCore
@testable import deltachat_ios
import UIKit

@Suite(.serialized) class DcTests {
    lazy var context = DcTestContext.newOfflineAccount(named: "Main")
    lazy var secondaryContext = DcTestContext.newOfflineAccount(named: "Secondary")
    init() {
        #expect(DcAccounts.shared.select(id: context.id))
    }
    deinit {
        DcTestContext.cleanup()
    }

    @Test @MainActor func webxdcShouldNotLeak() async throws {
        // send a webxdc message
        let selfChat = context.createChatByContactId(contactId: Int(DC_CONTACT_ID_SELF))
        let chess = Bundle.module.url(forResource: "chess", withExtension: "xdc")!
        let xdcMessage = context.newMessage(viewType: DC_MSG_WEBXDC)
        xdcMessage.setFile(filepath: chess.path)
        context.sendMessage(chatId: selfChat, message: xdcMessage)
        
        // test if webxdc vc deinits after being presented and then dismissed
        let window = UIWindow()
        let vc = UIViewController()
        window.rootViewController = vc
        window.windowLevel = .alert
        window.makeKeyAndVisible()
        vc.present(WebxdcViewController(dcContext: context, messageId: xdcMessage.id), animated: false)
        weak var webxdcVC = vc.presentedViewController as? WebxdcViewController
        #expect(webxdcVC != nil)
        await webxdcVC!.dismiss(animated: false)
        #expect(webxdcVC == nil)
    }

    @Test @MainActor func shareAttachmentToDifferentProfileKeepsFileBytes() async throws {
        #expect(DcAccounts.shared.getSelected().id == context.id)

        try? FileManager.default.removeItem(at: shareExtensionDirectory)
        try FileManager.default.createDirectory(at: shareExtensionDirectory, withIntermediateDirectories: true)
        let fileURL = shareExtensionDirectory.appendingPathComponent("shared-file.txt")
        let sharedBytes = Data([0x44, 0x65, 0x6c, 0x74, 0x61])
        try sharedBytes.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: shareExtensionDirectory) }

        let provider = CodableNSItemProvider.contentsAt(url: fileURL, viewType: DC_MSG_FILE)
        let shareItems = try #require(ValidatedShareItems([provider]))
        RelayHelper.shared.setShareItems(items: shareItems)

        #expect(DcAccounts.shared.select(id: secondaryContext.id))
        let chatB = secondaryContext.createChatByContactId(contactId: Int(DC_CONTACT_ID_SELF))
        RelayHelper.shared.shareAndFinishRelaying(to: chatB)

        let ids = secondaryContext.getChatMsgs(chatId: chatB, flags: 0)
        #expect(!ids.isEmpty)
        if let lastId = ids.last {
            let msg = secondaryContext.getMessage(id: lastId)
            #expect(msg.type == DC_MSG_FILE)
            #expect(msg.filesize > 0)
        }
        #expect(DcAccounts.shared.select(id: context.id))
    }

    @Test @MainActor func invalidDeeplinkIdsAreRejected() throws {
        let coordinator = AppCoordinator(window: UIWindow(), dcAccounts: DcAccounts.shared)
        let accountId = context.id
        let invalidChatId = 999

        let urls = [
            "chat.delta.deeplink://chat?accountId=-1&chatId=1",
            "chat.delta.deeplink://chat?accountId=\(accountId)&chatId=-1",
            "chat.delta.deeplink://chat?accountId=\(accountId)&chatId=4294967296",
            "chat.delta.deeplink://chat?accountId=\(accountId)&chatId=\(invalidChatId)",
            "chat.delta.deeplink://chat?accountId=\(accountId)&chaId=-1",
            "chat.delta.deeplink://webxdc?accountId=\(accountId)&chatId=-1&msgId=-1",
            "chat.delta.deeplink://share?data=%5B%5D&accountId=-1",
            "chat.delta.deeplink://share?data=%5B%5D&accountId=invalid",
            "chat.delta.deeplink://share?data=%5B%5D&accountId=\(accountId)&chatId=-1",
            "chat.delta.deeplink://share?data=%5B%5D&accountId=\(accountId)&chatId=invalid",
            "chat.delta.deeplink://share?data=%5B%5D&accountId=\(accountId)&chatId=\(invalidChatId)",
        ]

        for urlString in urls {
            let url = try #require(URL(string: urlString))
            #expect(coordinator.handleDeepLinkURL(url) == false, "Expected to reject \(urlString)")
        }
    }

    @Test @MainActor func optionalShareDeeplinkIdsCanBeOmitted() throws {
        #expect(DcAccounts.shared.select(id: context.id))
        let coordinator = AppCoordinator(window: UIWindow(), dcAccounts: DcAccounts.shared)
        let accountId = context.id
        let chatId = context.createChatByContactId(contactId: Int(DC_CONTACT_ID_SELF))
        let urls = [
            "chat.delta.deeplink://share?data=%5B%5D",
            "chat.delta.deeplink://share?data=%5B%5D&accountId=\(accountId)",
            "chat.delta.deeplink://share?data=%5B%5D&chatId=\(chatId)",
            "chat.delta.deeplink://share?data=%5B%5D&accountId=\(accountId)&chatId=\(chatId)",
        ]

        for urlString in urls {
            let url = try #require(URL(string: urlString))
            #expect(coordinator.handleDeepLinkURL(url), "Expected to accept \(urlString)")
        }
    }

    @Test @MainActor func shareDeeplinkFilesStayInsideStagingDirectory() throws {
        #expect(DcAccounts.shared.select(id: context.id))
        RelayHelper.shared.finishRelaying()

        let fileManager = FileManager.default
        let coordinator = AppCoordinator(window: UIWindow(), dcAccounts: DcAccounts.shared)
        let stagingParent = shareExtensionDirectory.deletingLastPathComponent()
        let identifier = UUID().uuidString
        let privateFile = stagingParent.appendingPathComponent("private-\(identifier).txt")
        let siblingDirectory = stagingParent.appendingPathComponent("share_extension_\(identifier)", isDirectory: true)
        let siblingFile = siblingDirectory.appendingPathComponent("file.txt")
        let stagedFile = shareExtensionDirectory.appendingPathComponent("staged-\(identifier).txt")
        let stagedSymlink = shareExtensionDirectory.appendingPathComponent("link-\(identifier).txt")

        try fileManager.createDirectory(at: shareExtensionDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: siblingDirectory, withIntermediateDirectories: true)
        try Data("private".utf8).write(to: privateFile)
        try Data("sibling".utf8).write(to: siblingFile)
        try fileManager.createSymbolicLink(at: stagedSymlink, withDestinationURL: privateFile)
        defer {
            RelayHelper.shared.finishRelaying()
            try? fileManager.removeItem(at: privateFile)
            try? fileManager.removeItem(at: siblingDirectory)
            try? fileManager.removeItem(at: stagedFile)
            try? fileManager.removeItem(at: stagedSymlink)
        }

        let traversalURL = shareExtensionDirectory.appendingPathComponent("../\(privateFile.lastPathComponent)")
        let rejectedURLs = [
            privateFile,
            siblingFile,
            traversalURL,
            stagedSymlink,
            shareExtensionDirectory,
            try #require(URL(string: "https://example.org/file.txt")),
        ]

        for fileURL in rejectedURLs {
            let items = [
                CodableNSItemProvider.text(text: "keep validation all-or-nothing"),
                .contentsAt(url: fileURL, viewType: DC_MSG_FILE),
            ]
            #expect(coordinator.handleDeepLinkURL(try makeShareDeeplink(items: items)) == false)
            #expect(RelayHelper.shared.isSharing() == false)
        }

        try Data("staged".utf8).write(to: stagedFile)
        let validItems = [CodableNSItemProvider.contentsAt(url: stagedFile, viewType: DC_MSG_FILE)]
        #expect(coordinator.handleDeepLinkURL(try makeShareDeeplink(items: validItems)))
        #expect(RelayHelper.shared.isSharing())
        if case .share(let shareItems) = RelayHelper.shared.data {
            guard case .contentsAt(let url, _) = try #require(shareItems.providers.first) else {
                Issue.record("Expected a staged file provider")
                return
            }
            #expect(url == stagedFile.standardizedFileURL.resolvingSymlinksInPath())
        } else {
            Issue.record("Expected validated share items")
        }
    }

    @Test func fileHelperConfinesUntrustedFilenames() throws {
        #expect(FileHelper.safeFilename("../../accounts.toml") == "accounts.toml")
        #expect(FileHelper.safeFilename("folder\\secret.txt") == "secret.txt")
        #expect(FileHelper.safeFilename("..") == "file")

        let path = try #require(FileHelper.saveData(
            data: Data("test".utf8),
            name: "../../accounts.toml",
            directory: .cachesDirectory
        ))
        defer { FileHelper.deleteFile(path) }

        let fileURL = URL(fileURLWithPath: path).standardizedFileURL
        let caches = try #require(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let identifier = try #require(Bundle.main.bundleIdentifier)
        let expectedDirectory = caches.appendingPathComponent(identifier, isDirectory: true).standardizedFileURL
        #expect(fileURL.deletingLastPathComponent() == expectedDirectory)
        #expect(fileURL.lastPathComponent == "accounts.toml")
    }

    @Test func externalURLPolicyRejectsLocalAndApplicationSchemes() throws {
        #expect(try #require(URL(string: "https://delta.chat/source")).isHTTPURL)
        #expect(try #require(URL(string: "http://example.org/source")).isHTTPURL)
        #expect(try #require(URL(string: "chat.delta.deeplink://share?data=x")).isHTTPURL == false)
        #expect(try #require(URL(string: "file:///private/account.toml")).isHTTPURL == false)
    }

    private func makeShareDeeplink(items: [CodableNSItemProvider]) throws -> URL {
        let encodedItems = try JSONEncoder().encode(items)
        let json = try #require(String(data: encodedItems, encoding: .utf8))
        var components = URLComponents()
        components.scheme = "chat.delta.deeplink"
        components.host = "share"
        components.queryItems = [.init(name: "data", value: json)]
        return try #require(components.url)
    }
}


struct DcTestContext {
    static func cleanup() {
        let accounts = DcAccounts.shared.getAll().compactMap(DcAccounts.shared.get(id:))
        for context in accounts where context.getConfigBool("ui.ios.test_account") {
            assert(DcAccounts.shared.remove(id: context.id))
        }
    }
    
    static func newOfflineAccount(named name: String) -> DcContext {
        let newAccountId = DcAccounts.shared.add()
        let newAccount = DcAccounts.shared.get(id: newAccountId)
        newAccount.setConfig("displayname", "Unit Test Account \(name)")
        newAccount.setConfig("addr", "ios.test.\(name)@delta.chat")
        newAccount.setConfig("configured_addr", "ios.test.\(name)@delta.chat")
        newAccount.setConfig("configured_mail_pw", "abcd")
        newAccount.setConfigBool("bcc_self", false)
        newAccount.setConfigBool("ui.ios.test_account", true)
        newAccount.setConfigBool("configured", true)
        return newAccount
    }
}

extension UIViewController {
    func dismiss(animated: Bool) async {
        await withCheckedContinuation { continuation in
            dismiss(animated: animated, completion: continuation.resume)
        }
    }
}

extension UIView {
    func saveSnapshot(named name: String) throws {
        let thisFile = #filePath
        let snapFile = "file://" + thisFile
            .split(separator: "/", omittingEmptySubsequences: false)
            .dropLast()
            .map(String.init)
            .appending("snapshots")
            .appending(name + ".png")
            .joined(separator: "/")
        try asImage().pngData()!.write(to: URL(string: snapFile)!)
    }
    
    func asImage() -> UIImage {
        UIGraphicsImageRenderer(size: bounds.size).image { _ in
            drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
    }
}

extension Array {
    func appending(_ newElement: Element) -> [Element] {
        var result = self
        result.append(newElement)
        return result
    }
}

extension Task where Failure == Never, Success == Never {
    static func sleep(seconds: Double) async throws {
        let nanoseconds = (seconds * 1_000_000_000).rounded(.down)
        try await sleep(nanoseconds: UInt64(exactly: nanoseconds) ?? 0)
    }
}

extension Bundle {
    @objc private class _This: NSObject {}
    internal static var module: Bundle {
        Bundle(for: _This.self)
    }
}
