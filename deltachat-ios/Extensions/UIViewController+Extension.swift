//
//  TableViewController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

extension UIViewController {
  func updateTitleView(title: String, subtitle: String?, baseColor: UIColor = .darkText) {
    let titleLabel = UILabel(frame: CGRect(x: 0, y: -2, width: 0, height: 0))
    titleLabel.backgroundColor = UIColor.clear
    titleLabel.textColor = baseColor
    titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    titleLabel.text = title
    titleLabel.textAlignment = .center
    titleLabel.adjustsFontSizeToFitWidth = true
    titleLabel.sizeToFit()

    let subtitleLabel = UILabel(frame: CGRect(x: 0, y: 18, width: 0, height: 0))
    subtitleLabel.textColor = baseColor.withAlphaComponent(0.95)
    subtitleLabel.font = UIFont.systemFont(ofSize: 12)
    subtitleLabel.text = subtitle
    subtitleLabel.textAlignment = .center
    subtitleLabel.adjustsFontSizeToFitWidth = true
    subtitleLabel.sizeToFit()

    let titleView = UIView(frame: CGRect(x: 0, y: 0, width: max(titleLabel.frame.size.width, subtitleLabel.frame.size.width), height: 30))
    titleView.addSubview(titleLabel)
    if subtitle != nil {
      titleView.addSubview(subtitleLabel)
    } else {
      titleLabel.frame = titleView.frame
    }
    let widthDiff = subtitleLabel.frame.size.width - titleLabel.frame.size.width
    if widthDiff < 0 {
      let newX = widthDiff / 2
      subtitleLabel.frame.origin.x = abs(newX)
    } else {
      let newX = widthDiff / 2
      titleLabel.frame.origin.x = newX
    }

    navigationItem.titleView = titleView
  }
}
