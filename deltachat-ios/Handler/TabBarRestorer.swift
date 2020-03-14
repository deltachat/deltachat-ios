import UIKit

class TabBarRestorer: NSObject, UITabBarControllerDelegate {

    private let lastActiveTabKey = "last_active_tab"
    private let offsetKey = 10

    // UserDefaults returns 0 by default which conflicts with tab 0 -> therefore we map our tab indexes by adding an offsetKey

    private enum Tab: Int {
        case qrTab = 10
        case chatTab = 11
        case settingsTab = 12
        case firstLaunch = 0
    }

    func restoreLastActiveTab() -> Int {

        let restoredTab = UserDefaults.standard.integer(forKey: lastActiveTabKey)

        guard let lastTab = Tab(rawValue: restoredTab) else {
            safe_fatalError("invalid restored tab")
            return -1
        }

        switch lastTab {
        case .qrTab, .chatTab, .settingsTab:
            return lastTab.rawValue - offsetKey
        case .firstLaunch:
            return -1
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let activeTab = tabBarController.selectedIndex + offsetKey
        UserDefaults.standard.set(activeTab, forKey: lastActiveTabKey)
        UserDefaults.standard.synchronize()
    }


}
