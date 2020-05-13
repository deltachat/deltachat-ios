import JGProgressHUD
import UIKit

class HudHandler {
    var backupHud: JGProgressHUD?
    weak var view: UIView?

    init(parentView: UIView) {
        view = parentView
    }

    func setHudProgress(_ progress: Int) {
        if let hud = self.backupHud {
            hud.progress = Float(progress) / 1000.0
            hud.detailTextLabel.text = "\(progress / 10)%"
        }
    }

    func showHud(_ text: String) {
        DispatchQueue.main.async {
            let hud = JGProgressHUD(style: .dark)
            hud.vibrancyEnabled = true
            hud.indicatorView = JGProgressHUDPieIndicatorView()
            hud.detailTextLabel.text = "0%"
            hud.textLabel.text = text
            if let view = self.view {
                hud.show(in: view)
            }
            self.backupHud = hud
        }
    }

    func setHudError(_ message: String?) {
        if let hud = self.backupHud {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                UIView.animate(
                    withDuration: 0.1, animations: {
                        hud.textLabel.text = message ?? String.localized("error")
                        hud.detailTextLabel.text = nil
                        hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    }
                )
                hud.dismiss(afterDelay: 5.0)
            }
        }
    }

    func setHudDone(callback: (() -> Void)?) {
        let delay = 1.0

        if let hud = self.backupHud {
            hud.setProgress(1.0, animated: true)
            hud.detailTextLabel.text = "100%"
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                UIView.animate(
                    withDuration: 0.1, animations: {
                        hud.textLabel.text = String.localized("done")
                        hud.detailTextLabel.text = nil
                        hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                    }
                )
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                callback?()
                hud.dismiss()
            }
        }
    }
}
