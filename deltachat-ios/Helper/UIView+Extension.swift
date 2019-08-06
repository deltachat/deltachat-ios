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
	
	func constraintAlignTopTo(_ view: UIView, paddingTop: CGFloat) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .top,
			relatedBy: .equal,
			toItem: view,
			attribute: .top,
			multiplier: 1.0,
			constant: paddingTop)
	}

	func constraintAlignBottomTo(_ view: UIView) -> NSLayoutConstraint {
		return constraintAlignBottomTo(view, paddingBottom: 0.0)
	}

	func constraintAlignBottomTo(_ view: UIView, paddingBottom: CGFloat) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .bottom,
			relatedBy: .equal,
			toItem: view,
			attribute: .bottom,
			multiplier: 1.0,
			constant: -paddingBottom)
	}

	func constraintAlignLeadingTo(_ view: UIView) -> NSLayoutConstraint {
		return constraintAlignLeadingTo(view, paddingLeading: 0.0)
	}

	func constraintAlignLeadingTo(_ view: UIView, paddingLeading: CGFloat) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .leading,
			relatedBy: .equal,
			toItem: view,
			attribute: .leading,
			multiplier: 1.0,
			constant: paddingLeading)
	}
	
	func constraintAlignTrailingTo(_ view: UIView) -> NSLayoutConstraint {
		return constraintAlignTrailingTo(view, paddingTrailing: 0.0)
	}

	func constraintAlignTrailingTo(_ view: UIView, paddingTrailing: CGFloat) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .trailing,
			relatedBy: .equal,
			toItem: view,
			attribute: .trailing,
			multiplier: 1.0,
			constant: -paddingTrailing)
	}

	func constraintToBottomOf(_ view: UIView) -> NSLayoutConstraint {
		return constraintToBottomOf(view, paddingTop: 8)
	}
	
	func constraintToBottomOf(_ view: UIView, paddingTop: CGFloat) -> NSLayoutConstraint {
		return NSLayoutConstraint(
			item: self,
			attribute: .top,
			relatedBy: .equal,
			toItem: view,
			attribute: .bottom,
			multiplier: 1.0,
			constant: paddingTop)
	}

	func constraintCenterXTo(_ view: UIView) -> NSLayoutConstraint {
		return NSLayoutConstraint(item: self,
								  attribute: .centerX,
								  relatedBy: .equal,
								  toItem: view,
								  attribute: .centerX,
								  multiplier: 1.0,
								  constant: 0.0)
	}

	func constraintCenterYTo(_ view: UIView) -> NSLayoutConstraint {
		return NSLayoutConstraint(item: self,
								  attribute: .centerY,
								  relatedBy: .equal,
								  toItem: view,
								  attribute: .centerY,
								  multiplier: 1.0,
								  constant: 0.0)
	}

}
