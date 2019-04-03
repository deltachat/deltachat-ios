//
//  String+Extension.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 03.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import Foundation

extension String {

	func containsCharacters() -> Bool {
		return !self.trimmingCharacters(in: [" "]).isEmpty
	}
}
