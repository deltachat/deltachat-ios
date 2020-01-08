//
//  DcUtils.swift
//  deltachat-ios
//
//  Created by Macci on 07.01.20.
//  Copyright © 2020 Jonas Reinsch. All rights reserved.
//

import Foundation

class DcUtils {
    static func copyAndFreeArray(inputArray: OpaquePointer?) -> [Int] {
        var acc: [Int] = []
        let len = dc_array_get_cnt(inputArray)
        for i in 0 ..< len {
            let e = dc_array_get_id(inputArray, i)
            acc.append(Int(e))
        }
        dc_array_unref(inputArray)

        return acc
    }

    static func copyAndFreeArrayWithLen(inputArray: OpaquePointer?, len: Int = 0) -> [Int] {
        var acc: [Int] = []
        let arrayLen = dc_array_get_cnt(inputArray)
        let start = max(0, arrayLen - len)
        for i in start ..< arrayLen {
            let e = dc_array_get_id(inputArray, i)
            acc.append(Int(e))
        }
        dc_array_unref(inputArray)

        return acc
    }

    static func copyAndFreeArrayWithOffset(inputArray: OpaquePointer?, len: Int = 0, from: Int = 0, skipEnd: Int = 0) -> [Int] {
        let lenArray = dc_array_get_cnt(inputArray)
        if lenArray <= skipEnd || lenArray == 0 {
            dc_array_unref(inputArray)
            return []
        }

        let start = lenArray - 1 - skipEnd
        let end = max(0, start - len)
        let finalLen = start - end + (len > 0 ? 0 : 1)
        var acc: [Int] = [Int](repeating: 0, count: finalLen)

        for i in stride(from: start, to: end, by: -1) {
            let index = finalLen - (start - i) - 1
            acc[index] = Int(dc_array_get_id(inputArray, i))
        }

        dc_array_unref(inputArray)
        //logger.info("got: \(from) \(len) \(lenArray) - \(acc)")

        return acc
    }
}
