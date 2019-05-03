//
//  Location.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 03.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import CoreLocation
import Foundation
import MessageKit


struct Location: LocationItem {
	var location: CLLocation

	var size: CGSize

	init(location: CLLocation, size: CGSize) {
		self.location = location
		self.size = size
	}
}
