import ActivityKit
import DcCore
import UIKit

struct WebxdcLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let info: WebxdcInfo
        let connectivity: Int32
    }

    let contextId: Int
    let chatId: Int
    let chatName: String
    let messageId: Int

    init(context: DcContext, messageId: Int) {
        self.contextId = context.id
        let msg = context.getMessage(id: messageId)
        self.chatId = msg.chatId
        let chat = context.getChat(chatId: chatId)
        self.chatName = chat.name
        self.messageId = messageId
        if let image = msg.getWebxdcPreviewImage() {
            LiveActivityIconStore.saveThumbnail(image, contextId: contextId, messageId: messageId)
        }
    }

    var previewImage: UIImage? {
        LiveActivityIconStore.loadThumbnail(contextId: contextId, messageId: messageId)
    }

    var url: URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = "chat.delta.deeplink"
        urlComponents.host = "webxdc"
        urlComponents.queryItems = [
            URLQueryItem(name: "msgId", value: "\(messageId)"),
            URLQueryItem(name: "chatId", value: "\(chatId)"),
            URLQueryItem(name: "accountId", value: "\(contextId)"),
        ]
        return urlComponents.url!
    }
}

private enum LiveActivityIconStore {
    static let appGroupID = "group.chat.delta.ios"

    static func url(contextId: Int, messageId: Int) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("live-activity-icons", isDirectory: true)
            .appendingPathComponent("\(contextId)_\(messageId).jpg")
    }

    static func saveThumbnail(_ image: UIImage, contextId: Int, messageId: Int, maxSize: CGFloat = 96) {
        guard let fileURL = url(contextId: contextId, messageId: messageId) else { return }

        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let thumb = resize(image, maxSize: maxSize)
        guard let data = thumb.jpegData(compressionQuality: 0.82) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func loadThumbnail(contextId: Int, messageId: Int) -> UIImage? {
        guard let fileURL = url(contextId: contextId, messageId: messageId),
              let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private static func resize(_ source: UIImage, maxSize: CGFloat) -> UIImage {
        let s = source.size
        guard s.width > 0, s.height > 0 else { return source }
        let factor = min(1, maxSize / max(s.width, s.height))
        let target = CGSize(width: floor(s.width * factor), height: floor(s.height * factor))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

import AppIntents

@available(iOS 16, *)
struct QuitWebxdcIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Quit a webxdc that is running in the background"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Context ID", default: 0) var contextId: Int
    @Parameter(title: "Message ID", default: 0) var messageId: Int

    init(contextId: Int, messageId: Int) {
        self.contextId = contextId
        self.messageId = messageId
    }

    init() {}

    func perform() async throws -> some IntentResult {
        // LiveActivityIntent is always performed in the main app process but it does
        // need to compile for the widget target.
        #if MAIN_APPLICATION
        await WebxdcViewController.loadedWebxdcs[.key(contextId: contextId, messageId: messageId)]?.quit()
        #endif
        return .result()
    }
}
