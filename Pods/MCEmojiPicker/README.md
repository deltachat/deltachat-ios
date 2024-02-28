# MCEmojiPicker

[![Version](https://img.shields.io/cocoapods/v/MCEmojiPicker.svg?style=flat)](https://cocoapods.org/pods/MCEmojiPicker)
[![License](https://img.shields.io/cocoapods/l/MCEmojiPicker.svg?style=flat)](https://cocoapods.org/pods/MCEmojiPicker)
[![Platform](https://img.shields.io/cocoapods/p/MCEmojiPicker.svg?style=flat)](https://cocoapods.org/pods/MCEmojiPicker)

<p float="left">
<img src="https://user-images.githubusercontent.com/50948518/216799717-25b3e4ed-b4c5-4166-91a2-72374b0564f9.gif" width="280">
</p>

## About

<b>It is a customizable library implementing macOS style emoji picker popover.</b>
<br><br>
If you are interested in how I developed it and what difficulties I encountered in the process, you can read an article on [Medium](https://medium.com/@izzyumkin/an-emoji-selection-element-aka-emojipicker-for-ios-like-in-macos-e2fa022b80af), [Habr](https://habr.com/ru/post/716194/) about it.
And if you like the project, don't forget to `put star ★`.

#### Limitations
- Does not support two part emojis. For example:
  - [x] Supported: 🤝🏻 🤝🏿
  - [ ] Not supported: 🫱🏿‍🫲🏻 🫱🏼‍🫲🏿
  
If you know how to fix it - welcome to the [discussion](https://github.com/izyumkin/MCEmojiPicker/discussions/10).

## Apps Using

<p float="left">
    <a href="https://apps.apple.com/app/id1500111859"><img src="http://izyumkin.ru/MCEmojiPicker/AppsUsing/id1500111859.png" height="65"></a>
    <a href="https://apps.apple.com/app/id6450279059"><img src="https://izyumkin.ru/MCEmojiPicker/AppsUsing/id6450279059.png" height="65"></a>
    <a href="https://apps.apple.com/app/id6444636956"><img src="https://izyumkin.ru/MCEmojiPicker/AppsUsing/id6444636956.png" height="65"></a>
</p>

If you use a `MCEmojiPicker`, add your application via Pull Request. Fore more information you can see [contribution guide](https://github.com/izyumkin/MCEmojiPicker/blob/main/CONTRIBUTING.md).

## Navigation

- [Requirements](#requirements)
- [Installation](#installation)
    - [CocoaPods](#cocoapods)
    - [Swift Package Manager](#swift-package-manager)
    - [Manually](#manually)
- [Quick Start](#quick-start)
- [Usage](#usage)
    - [Selected emoji category tint color](#selected-emoji-category-tint-color)
    - [Arrow direction](#arrow-direction)
    - [Horizontal inset](#horizontal-inset)
    - [Is dismiss after choosing](#is-dismiss-after-choosing)
    - [Custom height](#custom-height)
    - [Feedback generator style](#feedback-generator-style)
- [SwiftUI](#swiftui)
- [Localization](#localization)
- [TODO](#todo)

## Requirements

- Swift `4.2` & `5.0`
- Ready for use on iOS 12.0+
- SwiftUI is supported from iOS 13.0

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate `MCEmojiPicker` into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'MCEmojiPicker'
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for managing the distribution of Swift code. It’s integrated with the Swift build system to automate the process of downloading, compiling, and linking dependencies.

To integrate `MCEmojiPicker` into your Xcode project using Xcode 11, specify it in `Project > Swift Packages`:

```ogdl
https://github.com/izyumkin/MCEmojiPicker
```

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate `MCEmojiPicker` into your project manually. Put `Source/MCEmojiPicker` folder in your Xcode project. Make sure to enable `Copy items if needed` and `Create groups`.

## Quick Start
Create `UIButton` and add selector as action:
```swift
@objc private func selectEmojiAction(_ sender: UIButton) {
    let viewController = MCEmojiPickerViewController()
    viewController.delegate = self
    viewController.sourceView = sender
    present(viewController, animated: true)
}
```

And then recieve emoji in the delegate method:
```swift
extension ViewController: MCEmojiPickerDelegate {
    func didGetEmoji(emoji: String) {
        emojiButton.setTitle(emoji, for: .normal)
    }
}
```

## Usage

`sourceView` is the view containing the anchor rectangle for the popover. You can create any `UIView` instance and set it in this property. 

### Selected emoji category tint color
Color for the selected emoji category. The default value of this property is `.systemBlue`.

```swift
viewController.selectedEmojiCategoryTintColor = .systemRed
```

### Arrow direction
The direction of the arrow for EmojiPicker. The default value of this property is `.up`.

```swift
viewController.arrowDirection = .up
```

### Horizontal inset
Inset from the `sourceView` border. The default value of this property is `0`.

```swift
viewController.horizontalInset = 0
```

### Is dismiss after choosing
Defines whether to dismiss emoji picker or not after choosing. The default value of this property is `true`.

```swift
viewController.isDismissAfterChoosing = true
```

### Custom height
Custom height for EmojiPicker. The default value of this property is `nil`.

```swift
viewController.customHeight = 300
```

### Feedback generator style
Feedback generator style. To turn off, set `nil` to this parameter. The default value of this property is `.light`.

```swift
viewController.feedBackGeneratorStyle = .soft
```

## SwiftUI

Use like system popover. All settings are available in the method initializer.

```swift
Button(selectedEmoji) {
    isPresented.toggle()
}.emojiPicker(
    isPresented: $isPresented,
    selectedEmoji: $selectedEmoji
)
```

or interact directly with the SwiftUI wrapper for the MCEmojiPickerViewController:

```swift
MCEmojiPickerRepresentableController(
    isPresented: $isPresented,
    selectedEmoji: $selectedEmoji,
    arrowDirection: .up,
    customHeight: 380.0,
    horizontalInset: .zero,
    isDismissAfterChoosing: true,
    selectedEmojiCategoryTintColor: .systemBlue,
    feedBackGeneratorStyle: .light
)
```

## Localization
🌍 This library supports all existing localizations

## TODO

-   [x] The main functionality for choosing emojis
-   [x] Dark mode
-   [x] Segmented control for jumping an emoji section
-   [x] Automatic adjustment of the relevant set of emoji for the iOS version
-   [x] Select skin tones from popup
-   [x] Frequently used
-   [ ] Search bar and search results
