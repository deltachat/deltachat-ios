import AppIntents
import DcCore
import UIKit

@available(iOS 16, *) // if you set this to 17, shortcuts crash delta chat
struct OpenWebXDCAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenWebXDCAppIntent(),
            phrases: [
                "Open \(\.$webxdcApp) in \(.applicationName)",
                "Open a webxdc app in \(.applicationName)",
            ],
            shortTitle: "Open a webxcd app"
        )
    }
}

@available(iOS 16, *)
struct OpenWebXDCAppIntent: AppIntent {
    @MainActor
    static var title: LocalizedStringResource = "Open webxcd app"

    @Parameter(title: "webxdc app", requestValueDialog: IntentDialog("Which webxdc app would you like to open?"))
    var webxdcApp: WebXDCAppEntity

    @MainActor
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: webxdcApp.id.deeplink) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct WebXDCAppEntity: AppEntity {
    var id: MsgID
    struct MsgID: Hashable, EntityIdentifierConvertible {
        var accountId: Int
        var chatId: Int
        var msgId: Int

        var deeplink: String {
            "chat.delta.deeplink://webxdc?accountId=\(accountId)&chatId=\(chatId)&msgId=\(msgId)"
        }

        var entityIdentifierString: String { deeplink }

        static func entityIdentifier(for entityIdentifierString: String) -> Self? {
            guard let parameters = URL(string: entityIdentifierString)?.queryParameters,
                  let accountId = parameters["accountId"].flatMap(Int.init),
                  let chatId = parameters["chatId"].flatMap(Int.init),
                  let messageId = parameters["msgId"].flatMap(Int.init)
            else { return nil }
            return ID(accountId: accountId, chatId: chatId, msgId: messageId)
        }
    }

    @MainActor
    init(accountId: Int, chat: DcChat, msg: DcMsg) {
        self.id = .init(accountId: accountId, chatId: msg.chatId, msgId: msg.id)
        let dict = msg.getWebxdcInfoDict()
        let document = dict["document"] as? String ?? ""
        let name = dict["name"] as? String ?? "ErrName" // name should not be empty
        self.title = document.isEmpty ? name : "\(document) – \(name)"
        self.subtitle = chat.name.isEmpty ? nil : "shared with " + chat.name
        self.icon = (dict["icon"] as? String).flatMap(msg.getWebxdcBlob(filename:))
    }

    var title: String
    var subtitle: String?
    var icon: Data?

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shared WebXDC App")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: subtitle.map { .init(stringLiteral: $0) },
            image: icon.map { .init(data: $0) }
        )
    }

    @MainActor
    static var defaultQuery = DefaultQuery()
    struct DefaultQuery: EntityQuery {
        @MainActor
        func entities(for identifiers: [WebXDCAppEntity.ID]) async throws -> [WebXDCAppEntity] {
            Dictionary(grouping: identifiers, by: \.accountId).flatMap { accountId, identifiersForAccount in
                let dcContext = DcAccounts.shared.get(id: accountId)
                return identifiersForAccount.map {
                    WebXDCAppEntity(accountId: accountId, chat: dcContext.getChat(chatId: $0.chatId), msg: dcContext.getMessage(id: $0.msgId))
                }
            }
        }


        @MainActor
        @available(iOS 17, *)
        var onlySuggestWebxdcApp: WebXDCAppEntity? {
            get { _onlySuggestWebxdcApp }
            set { _onlySuggestWebxdcApp = newValue }
        }
        /// Mutating this in iOS 16 crashes the app :)
        @MainActor private var _onlySuggestWebxdcApp: WebXDCAppEntity? {
            didSet { OpenWebXDCAppShortcuts.updateAppShortcutParameters() }
        }

        @MainActor
        func suggestedEntities() async throws -> [WebXDCAppEntity] {
            if #available(iOS 17, *), let onlySuggestWebxdcApp {
                return [onlySuggestWebxdcApp]
            } else {
                return DcAccounts.shared.getAll().flatMap { accountId in
                    let dcContext = DcAccounts.shared.get(id: accountId)
                    let webxdcMsgIds = dcContext.getChatMedia(chatId: 0, messageType: DC_MSG_WEBXDC, messageType2: 0, messageType3: 0)
                    return webxdcMsgIds.map { webxdcMsgId in
                        let msg = dcContext.getMessage(id: webxdcMsgId)
                        let chat = dcContext.getChat(chatId: msg.chatId)
                        return WebXDCAppEntity(accountId: accountId, chat: chat, msg: msg)
                    }
                }
            }
        }
    }
}
