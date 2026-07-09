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
        RelayHelper.shared.setShareItems(items: [provider])

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
