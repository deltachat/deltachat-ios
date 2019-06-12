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
    return !trimmingCharacters(in: [" "]).isEmpty
  }

  // O(n) - returns indexes of subsequences -> can be used to highlight subsequence within string
  func contains(subSequence: String) -> [Int] {
    if subSequence.count > count {
      return []
    }

    let str = lowercased()
    let sub = subSequence.lowercased()

    var j = 0

    var foundIndexes: [Int] = []

    for (index, char) in str.enumerated() {
      if j == sub.count {
        break
      }

      if char == sub.subScript(j) {
        foundIndexes.append(index)
        j += 1
      }
    }
    return foundIndexes.count == sub.count ? foundIndexes : []
  }

  func subScript(_ i: Int) -> Character {
    return self[index(startIndex, offsetBy: i)]
  }

  func boldAt(indexes: [Int], fontSize: CGFloat) -> NSAttributedString {
    let attributedText = NSMutableAttributedString(string: self)

    for index in indexes {
      if index < 0 || count <= index {
        break
      }
      attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: NSMakeRange(index, 1))
    }
    return attributedText
  }
}

extension URL {
  public var queryParameters: [String: String]? {
    guard
      let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
      let queryItems = components.queryItems else { return nil }
    return queryItems.reduce(into: [String: String]()) { result, item in
      result[item.name] = item.value
    }
  }
}

extension Dictionary {
  func percentEscaped() -> String {
    return map { key, value in
      let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
      let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
      return escapedKey + "=" + escapedValue
    }
    .joined(separator: "&")
  }
}

extension CharacterSet {
  static let urlQueryValueAllowed: CharacterSet = {
    let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
    let subDelimitersToEncode = "!$&'()*+,;="

    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
    return allowed
  }()
}

extension URLSession {
  func synchronousDataTask(request: URLRequest) -> (Data?, URLResponse?, Error?) {
    var data: Data?
    var response: URLResponse?
    var error: Error?

    let semaphore = DispatchSemaphore(value: 0)

    let task = dataTask(with: request) {
      data = $0
      response = $1
      error = $2

      semaphore.signal()
    }
    task.resume()

    _ = semaphore.wait(timeout: .distantFuture)

    return (data, response, error)
  }
}

extension MRContact {
  func contains(searchText text: String) -> [ContactHighlights] {
    var nameIndexes = [Int]()
    var emailIndexes = [Int]()

    let contactString = name + email
    let subsequenceIndexes = contactString.contains(subSequence: text)

    if !subsequenceIndexes.isEmpty {
      for index in subsequenceIndexes {
        if index < name.count {
          nameIndexes.append(index)
        } else {
          let emailIndex = index - name.count
          emailIndexes.append(emailIndex)
        }
      }
      return [ContactHighlights(contactDetail: .NAME, indexes: nameIndexes), ContactHighlights(contactDetail: .EMAIL, indexes: emailIndexes)]
    } else {
      return []
    }
  }
}

extension UIImage {

	func dcCompress(toMax target: Float = 1280) -> UIImage? {
		return resize(toMax: target)
	}

	func imageSizeInPixel() -> CGSize {
		let heightInPoints = size.height
		let heightInPixels = heightInPoints * scale
		let widthInPoints = size.width
		let widthInPixels = widthInPoints * scale
		return CGSize(width: widthInPixels, height: heightInPixels)
	}

	// source: https://stackoverflow.com/questions/29137488/how-do-i-resize-the-uiimage-to-reduce-upload-image-size // slightly changed
	func resize(toMax: Float) -> UIImage? {
		var actualHeight = Float(size.height)
		var actualWidth = Float(size.width)
		let maxHeight: Float = toMax
		let maxWidth: Float = toMax
		var imgRatio: Float = actualWidth / actualHeight
		let maxRatio: Float = maxWidth / maxHeight
		let compressionQuality: Float = 0.5
		//50 percent compression
		if actualHeight > maxHeight || actualWidth > maxWidth {
			if imgRatio < maxRatio {
				//adjust width according to maxHeight
				imgRatio = maxHeight / actualHeight
				actualWidth = imgRatio * actualWidth
				actualHeight = maxHeight
			} else if imgRatio > maxRatio {
				//adjust height according to maxWidth
				imgRatio = maxWidth / actualWidth
				actualHeight = imgRatio * actualHeight
				actualWidth = maxWidth
			} else {
				actualHeight = maxHeight
				actualWidth = maxWidth
			}
		}

		let rect = CGRect(x: 0.0, y: 0.0, width: CGFloat(actualWidth), height: CGFloat(actualHeight))
		UIGraphicsBeginImageContext(rect.size)
		draw(in: rect)
		let img = UIGraphicsGetImageFromCurrentImageContext()
		let imageData = img?.jpegData(compressionQuality: CGFloat(compressionQuality))
		UIGraphicsEndImageContext()
		return UIImage(data: imageData!)
	}
}

extension UIView {
	func makeBorder(color: UIColor = UIColor.red) {
		self.layer.borderColor = color.cgColor
		self.layer.borderWidth = 2
	}
}
