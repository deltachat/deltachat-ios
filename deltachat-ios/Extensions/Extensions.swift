//
//  String+Extension.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 03.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

extension String {

	func containsCharacters() -> Bool {
		return !self.trimmingCharacters(in: [" "]).isEmpty
	}
}

extension UIColor {

	static var systemBlue: UIColor {
		return UIButton(type: .system).tintColor
	}

}
