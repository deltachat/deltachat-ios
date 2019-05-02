//
//  deltachat_iosTests.swift
//  deltachat-iosTests
//
//  Created by Bastian van de Wetering on 02.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import XCTest
@testable import deltachat_ios

class DeltachatTests: XCTestCase {

	var appleseedContact: MRContact!

	override func setUp() {
		let contactIds = Utils.getContactIds()

		let contacts = contactIds.map({ return MRContact(id: $0) })

		appleseedContact = contacts.filter({$0.name == "John Appleseed"}).first
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testContactSearchForSubsequences() {
		XCTAssert(appleseedContact.name == "John Appleseed", "Test contacts name is John Appleseed")
		XCTAssert(appleseedContact.email == "John-Appleseed@mac.com", "Test contacts email is john.appleseed@mac.com")

		let indexDetailA = appleseedContact.contains(searchText: "jmc")

		XCTAssert(indexDetailA.count == 2)
		XCTAssert(indexDetailA[0].contactDetail == .NAME)
		XCTAssert(indexDetailA[0].indexes == [0])
		XCTAssert(indexDetailA[1].indexes == [15, 17])

		let indexDetailB = appleseedContact.contains(searchText: "joj")
		XCTAssert(indexDetailB[0].indexes == [0, 1])
		XCTAssert(indexDetailB[1].indexes == [0])

		let indexDetailC = appleseedContact.contains(searchText: "jojh")
		XCTAssert(indexDetailC[0].indexes == [0, 1])
		XCTAssert(indexDetailC[1].indexes == [0, 2])

		let indexDetailD = appleseedContact.contains(searchText: "joz")
		XCTAssert(indexDetailD.isEmpty)






	}


	func testPerformanceExample() {
		// This is an example of a performance test case.
		self.measure {
			// Put the code you want to measure the time of here.
		}
	}

}
