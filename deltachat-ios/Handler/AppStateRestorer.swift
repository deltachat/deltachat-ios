import UIKit

class AppStateRestorer {

    private let lastActiveTabKey = "last_active_tab3"
    private let lastActiveChatId = "last_active_chat_id"
    private let offsetKey = 11

    // UserDefaults returns 0 by default which conflicts with tab 0 -> therefore we map our tab indexes by adding an offsetKey

    private enum Tab: Int {
        case qrTab = 11 // there are two enums, here and at AppCoordinator (this is error prone and could probably be merged)
        case chatTab = 12
        case settingsTab = 13
        case firstLaunch = 0
    }

    static let shared: AppStateRestorer = AppStateRestorer()

    func restoreLastActiveTab() -> Int {
        let lastTab = Tab(rawValue: UserDefaults.standard.integer(forKey: lastActiveTabKey)) ?? .firstLaunch

        switch lastTab {
        case .qrTab, .chatTab, .settingsTab:
            return lastTab.rawValue - offsetKey
        case .firstLaunch:
            return -1
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let activeTab = tabBarController.selectedIndex + offsetKey

        if let tab = Tab(rawValue: activeTab), tab != .chatTab {
            resetLastActiveChat()
        }

        UserDefaults.standard.set(activeTab, forKey: lastActiveTabKey)
    }

    private func storeChat(chatId: Int?) {
        let value = chatId ?? -1
        UserDefaults.standard.set(value, forKey: lastActiveChatId)
    }

    func storeLastActiveChat(chatId: Int) {
        storeChat(chatId: chatId)
    }

    func resetLastActiveChat() {
        storeChat(chatId: nil)
    }

    func restoreLastActiveChatId() -> Int? {
        let restoredChatId = UserDefaults.standard.integer(forKey: lastActiveChatId)
        if restoredChatId == -1 || restoredChatId == 0 {
            return nil
        }
        return restoredChatId
    }
}
