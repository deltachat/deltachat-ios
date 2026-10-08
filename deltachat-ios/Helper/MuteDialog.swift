import UIKit

struct MuteDialog {
    private static let options: [(name: String, duration: Int)] = [
        ("mute_for_one_hour", Time.oneHour),
        ("mute_for_eight_hours", Time.eightHours),
        ("mute_for_one_day", Time.oneDay),
        ("mute_for_seven_days", Time.oneWeek),
        ("mute_forever", -1),
    ]
    public static func show(viewController: UIViewController, didSelectMute: @escaping (_ duration: Int) -> Void) {
        let alert = UIAlertController(title: String.localized("menu_mute"), message: nil, preferredStyle: .safeActionSheet)
        for (name, duration) in options {
            alert.addAction(UIAlertAction(title: String.localized(name), style: .default, handler: { _ in
                didSelectMute(duration)
            }))
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }

    @MenuElementBuilder
    static func menu(isMuted: Bool, didSelectMute: @escaping (_ duration: Int) -> Void) -> UIMenuElement {
        if isMuted {
            UIAction(
                title: String.localized("menu_unmute"),
                image: UIImage(systemName: "speaker.wave.2"),
                handler: { _ in didSelectMute(0) }
            )
        } else {
            UIMenu(title: String.localized("mute"), image: UIImage(systemName: "speaker.slash"), uncached: {
                for (name, duration) in options {
                    UIAction(
                        title: String.localized(name),
                        handler: { _ in didSelectMute(duration) }
                    )
                }
            })
        }
    }
}
