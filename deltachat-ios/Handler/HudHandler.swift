//
//  HudHandler.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 02.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import JGProgressHUD
import UIKit

class HudHandler {

	private lazy var alertView: UIAlertController = {
		let alertView = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
		alertView.addAction(UIAlertAction(title: nil, style: .cancel, handler: nil))
		return alertView
	}()

  // var backupHud: JGProgressHUD?
	var viewController: UIViewController

  init(parentView: UIViewController) {
    viewController = parentView
  }

  func setHudProgress(_ progress: Int) {
    //if let hud = self.alertView {
      //hud.progress = Float(progress) / 1000.0
      //hud.detailTextLabel.text = "\(progress / 10)% Complete"

  }

  func showBackupHud(_ text: String) {
			viewController.present(alertView, animated: false, completion: nil)
		


		/*
    DispatchQueue.main.async {
      let hud = JGProgressHUD(style: .dark)
      hud.vibrancyEnabled = true
      hud.indicatorView = JGProgressHUDPieIndicatorView()
      hud.detailTextLabel.text = "0% Complete"
      hud.textLabel.text = text
      hud.show(in: self.view)
      self.backupHud = hud
    }
		*/
  }

  func setHudError(_ message: String?) {
		/*
    if let hud = self.backupHud {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
        UIView.animate(
          withDuration: 0.1, animations: {
            hud.textLabel.text = message ?? "Error"
            hud.detailTextLabel.text = nil
            hud.indicatorView = JGProgressHUDErrorIndicatorView()
          }
        )
        hud.dismiss(afterDelay: 5.0)
      }
    }
		*/
  }

  func setHudDone(callback: (() -> Void)?) {
		/*
    let delay = 1.0

    if let hud = self.backupHud {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
        UIView.animate(
          withDuration: 0.1, animations: {
            hud.textLabel.text = "Success"
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
		*/
  }
}
