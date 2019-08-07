//
//  File.swift
//  deltachat-ios
//
//  Created by Macci on 05.08.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

extension UIView {
	func makeBorder(color: UIColor = UIColor.red) {
		self.layer.borderColor = color.cgColor
		self.layer.borderWidth = 2
	}

	func constraintAlignTopTo(_ view: UIView) -> NSLayoutConstraint {
		return constraintAlignTopTo(view, paddingTop: 0.0)
	}
	
	func constraintAlignTopTo(_ view: UIView, paddingTop: CGFloat = 0.0) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .top,
			relatedBy: .equal,
			toItem: view,
			attribute: .top,
			multiplier: 1.0,
			constant: paddingTop)
	}

	func constraintAlignBottomTo(_ view: UIView, paddingBottom: CGFloat = 0.0) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .bottom,
			relatedBy: .equal,
			toItem: view,
			attribute: .bottom,
			multiplier: 1.0,
			constant: -paddingBottom)
	}

	func constraintAlignLeadingTo(_ view: UIView, paddingLeading: CGFloat = 0.0) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .leading,
			relatedBy: .equal,
			toItem: view,
			attribute: .leading,
			multiplier: 1.0,
			constant: paddingLeading)
	}

	func constraintAlignTrailingTo(_ view: UIView, paddingTrailing: CGFloat = 0.0) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .trailing,
			relatedBy: .equal,
			toItem: view,
			attribute: .trailing,
			multiplier: 1.0,
			constant: -paddingTrailing)
	}
	
	func constraintToBottomOf(_ view: UIView, paddingTop: CGFloat = 0.0) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .top,
			relatedBy: .equal,
			toItem: view,
			attribute: .bottom,
			multiplier: 1.0,
			constant: paddingTop)
	}

	func constraintToTrailingOf(_ view: UIView, paddingLeading: CGFloat = 0.0) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .leading,
			relatedBy: .equal,
			toItem: view,
			attribute: .trailing,
			multiplier: 1.0,
			constant: paddingLeading)
	}


	func constraintCenterXTo(_ view: UIView, paddingX: CGFloat = 0.0) -> NSLayoutConstraint {
		return NSLayoutConstraint(item: self,
								  attribute: .centerX,
								  relatedBy: .equal,
								  toItem: view,
								  attribute: .centerX,
								  multiplier: 1.0,
								  constant: paddingX)
	}

	func constraintCenterYTo(_ view: UIView, paddingY: CGFloat = 0.0) -> NSLayoutConstraint {
		return NSLayoutConstraint(item: self,
								  attribute: .centerY,
								  relatedBy: .equal,
								  toItem: view,
								  attribute: .centerY,
								  multiplier: 1.0,
								  constant: paddingY)
	}

}
