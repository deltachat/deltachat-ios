//
//  DcArra.swift
//  DcCore
//
//  Created by Nathan Mattes on 17.01.24.
//  Copyright © 2024 merlinux GmbH. All rights reserved.
//

import Foundation

/// An object containing a simple array
///
/// See [dc_array_t Class Reference](https://c.delta.chat/classdc__array__t.html
public class DcArray {
    private var dcArrayPointer: OpaquePointer?

    public init(arrayPointer: OpaquePointer) {
        dcArrayPointer = arrayPointer
    }

    deinit {
        dc_array_unref(dcArrayPointer)
    }

    public var count: Int {
       return Int(dc_array_get_cnt(dcArrayPointer))
    }
}
