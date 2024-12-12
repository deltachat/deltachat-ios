import Foundation
import DcCore

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
}
