// The MIT License (MIT)
//
// Copyright © 2022 Ivan Izyumkin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

/// In SPM, the parameter `Bundle.module` is used to access resources, but in CocoaPods this is done differently.
/// In order for the library to support both dependency managers, it is necessary to add a similar parameter to the CocoaPods version.
///
/// To do this, a check has been added before the extension.
#if !SWIFT_PACKAGE
extension Bundle {
    /// Resources bundle.
    static var module: Bundle {
        let path = Bundle(for: MCUnicodeManager.self).path(
            forResource: "MCEmojiPicker",
            ofType: "bundle"
        ) ?? ""
        return Bundle(path: path) ?? Bundle.main
    }
}
#endif
