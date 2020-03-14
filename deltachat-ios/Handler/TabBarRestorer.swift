import UIKit

class TabBarRestorer: NSObject, UITabBarControllerDelegate {

    private let userDefaultKey = "last_active_tab"

    func restoreLastActiveTab() -> Int {
        return UserDefaults.standard.integer(forKey: userDefaultKey)
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let activeTab = tabBarController.selectedIndex
        UserDefaults.standard.set(activeTab, forKey: userDefaultKey)
        UserDefaults.standard.synchronize()
    }
}
