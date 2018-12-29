//
//  ProgressHud.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 28.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import JGProgressHUD

class ProgressHud {
    var hud: JGProgressHUD

    func error(_ message: String?, _ cb: (() -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            UIView.animate(
                withDuration: 0.1, animations: {
                    self.hud.textLabel.text = message ?? "Error"
                    self.hud.detailTextLabel.text = nil
                    self.hud.indicatorView = JGProgressHUDErrorIndicatorView()
                }
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5000)) {
                self.hud.dismiss()
                cb?()
            }
        }
    }

    func done(_ message: String? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            UIView.animate(
                withDuration: 0.1, animations: {
                    self.hud.textLabel.text = message ?? "Success"
                    self.hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                }
            )

            self.hud.dismiss(afterDelay: 1.0)
        }
    }

    func progress(_ progress: Int) {
        hud.progress = Float(progress) / 1000.0
        hud.detailTextLabel.text = "\(progress / 10)% Complete"
    }

    init(_ text: String, in view: UIView) {
        hud = JGProgressHUD(style: .dark)
        hud.vibrancyEnabled = true
        hud.indicatorView = JGProgressHUDPieIndicatorView()

        hud.detailTextLabel.text = "0% Complete"
        hud.textLabel.text = text
        hud.show(in: view)
    }
}
