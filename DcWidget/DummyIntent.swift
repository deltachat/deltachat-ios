import AppIntents
import os

/// This intent does nothing, it is used by the widget
/// when clicking outside of the buttons to not open the app.
/// This makes it harder to miss a tab.
struct DummyIntent: AppIntent {
    static var title: LocalizedStringResource = "Dummy Intent"

    // so this does not land in shortcuts or siri by accident
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
