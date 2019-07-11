import UIKit
import Reachability

final class DCNavigationController: UINavigationController {
  var stateChangedObserver: Any?

  override func viewDidLoad() {
    super.viewDidLoad()

    if #available(iOS 11.0, *) {
      navigationBar.prefersLargeTitles = true
    } else {
      navigationBar.setBackgroundImage(UIImage(), for: .default)
    }

    setShadow(nil)
  }

  private func setShadow(_ state: String?) {
    switch state {
    case "offline":
      navigationBar.shadowImage = Constants.defaultShadow
    case "online":
      navigationBar.shadowImage = Constants.onlineShadow
    default:
      navigationBar.shadowImage = Constants.defaultShadow
    }
  }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if let connection = Reachability()?.connection {
			switch connection {
			case Reachability.Connection.cellular, Reachability.Connection.wifi:
				setShadow("online")
			case Reachability.Connection.none:
				setShadow("offline")
			}
		}

		let nc = NotificationCenter.default
		stateChangedObserver = nc.addObserver(
			forName: dcNotificationStateChanged,
			object: nil,
			queue: nil
		) {
			notification in
			if let state = notification.userInfo?["state"] {
				self.setShadow(state as? String)
			}
		}
	}

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    let nc = NotificationCenter.default
    if let stateChangedObserver = self.stateChangedObserver {
      nc.removeObserver(stateChangedObserver)
    }
  }

}
