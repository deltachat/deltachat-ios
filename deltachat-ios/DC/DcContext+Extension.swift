import Foundation
import DcCore
import WidgetKit

@available(iOS 15, *)
extension DcContext {
    private static let key = "ui.ios.selected_apps_for_widget"
    func shownWidgets() -> [WidgetEntry] {
        guard let jsonData = getConfig(Self.key)?.data(using: .utf8) else { return [] }

        do {
            let widgets = try JSONDecoder().decode([WidgetEntry].self, from: jsonData)
            return widgets
        } catch {
            return []
        }
    }

    func storeShownWidgets(_ widgets: [WidgetEntry]) {
        guard let jsonData = try? JSONEncoder().encode(widgets),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        setConfig(Self.key, jsonString)
    }

    func addWebxdcToHomescreenWidget(messageId: Int) {
        let entry = WidgetEntry(accountId: self.id, messageId: messageId)
        var entries = shownWidgets()
        entries.insert(entry, at: entries.startIndex)

        storeShownWidgets(entries)
        WidgetCenter.shared.reloadTimelines(ofKind: "DcWebxdcWidget")
    }

    func removeWebxdcFromHomescreen(messageId: Int) {
        let entry = WidgetEntry(accountId: self.id, messageId: messageId)
        var entries = shownWidgets()
        entries.removeAll { $0 == entry }

        storeShownWidgets(entries)
        WidgetCenter.shared.reloadTimelines(ofKind: "DcWebxdcWidget")
    }
}
