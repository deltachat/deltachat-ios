import Foundation
import DcCore
import WidgetKit

@available(iOS 15, *)
extension UserDefaults {
    
    private static let key = "ui.ios.selected_apps_for_widget"

    func getAllWidgetEntries() -> [WidgetEntry] {
        guard let jsonData = data(forKey: Self.key) else { return [] }

        do {
            let widgets = try JSONDecoder().decode([WidgetEntry].self, from: jsonData)
            return widgets
        } catch {
            return []
        }
    }

    func storeWidgetEntries(_ widgets: [WidgetEntry]) {
        guard let jsonData = try? JSONEncoder().encode(widgets) else { return }

        setValue(jsonData, forKey: Self.key)
    }

    func addWebxdcToHomescreenWidget(accountId: Int, messageId: Int) {
        let entry = WidgetEntry(accountId: accountId, type: .app(messageId: messageId))
        var entries = getAllWidgetEntries()
        entries.insert(entry, at: entries.startIndex)

        storeWidgetEntries(entries)
        WidgetCenter.shared.reloadTimelines(ofKind: "DcWebxdcWidget")
    }

    func removeWebxdcFromHomescreen(accountId: Int, messageId: Int) {
        let entry = WidgetEntry(accountId: accountId, type: .app(messageId: messageId))
        var entries = getAllWidgetEntries()
        entries.removeAll { $0 == entry }

        storeWidgetEntries(entries)
        WidgetCenter.shared.reloadTimelines(ofKind: "DcWebxdcWidget")
    }

    func addChatToHomescreenWidget(accountId: Int, chatId: Int) {
        let entry = WidgetEntry(accountId: accountId, type: .chat(chatId: chatId))
        var entries = getAllWidgetEntries()
        entries.insert(entry, at: entries.startIndex)

        storeWidgetEntries(entries)
        WidgetCenter.shared.reloadTimelines(ofKind: "DcWebxdcWidget")
    }

    func removeChatFromHomescreenWidget(accountId: Int, chatId: Int) {
        let entry = WidgetEntry(accountId: accountId, type: .chat(chatId: chatId))
        var entries = getAllWidgetEntries()
        entries.removeAll { $0 == entry }

        storeWidgetEntries(entries)
        WidgetCenter.shared.reloadTimelines(ofKind: "DcWebxdcWidget")
    }
}
