import UIKit

struct MuteDialog {
    public static func show(viewController: UIViewController, callback: @escaping (_ duration: Int) -> Void) {
        let forever = -1
        let options: [(name: String, duration: Int)] = [
            ("mute_for_one_hour", Time.oneHour),
            ("mute_for_two_hours", Time.twoHours),
            ("mute_for_one_day", Time.oneDay),
            ("mute_for_seven_days", Time.oneWeek),
            ("mute_forever", forever),
        ]

        let alert = UIAlertController(title: String.localized("mute"), message: nil, preferredStyle: .safeActionSheet)
        for (name, duration) in options {
            alert.addAction(UIAlertAction(title: String.localized(name), style: .default, handler: { _ in
                callback(duration)
            }))
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }
}