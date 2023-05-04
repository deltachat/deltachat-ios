# SDWebImageSVGKitPlugin

[![CI Status](https://img.shields.io/travis/SDWebImage/SDWebImageSVGKitPlugin.svg?style=flat)](https://travis-ci.org/SDWebImage/SDWebImageSVGKitPlugin)
[![Version](https://img.shields.io/cocoapods/v/SDWebImageSVGKitPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageSVGKitPlugin)
[![License](https://img.shields.io/cocoapods/l/SDWebImageSVGKitPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageSVGKitPlugin)
[![Platform](https://img.shields.io/cocoapods/p/SDWebImageSVGKitPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageSVGKitPlugin)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/SDWebImage/SDWebImageSVGKitPlugin)


## What's for
SDWebImageSVGKitPlugin is a SVG coder plugin for [SDWebImage](https://github.com/rs/SDWebImage/) framework, which provide the image loading support for [SVG](https://en.wikipedia.org/wiki/Scalable_Vector_Graphics) using [SVGKit](https://github.com/SVGKit/SVGKit) SVG engine.

Note: iOS 13+/macOS 10.15+ supports native SVG rendering (called [Symbol Image](https://developer.apple.com/documentation/uikit/uiimage/configuring_and_displaying_symbol_images_in_your_ui/)), with system framework to load SVG. Check [SDWebImageSVGCoder](https://github.com/SDWebImage/SDWebImageSVGCoder) for more information.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

You can modify the code or use some other SVG files to check the compatibility.

## Requirements

+ iOS 9+
+ tvOS 9+
+ macOS 10.11+
+ Xcode 11+

## Installation

#### CocoaPods

SDWebImageSVGKitPlugin is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SDWebImageSVGKitPlugin'
```

#### Swift Package Manager (Xcode 11+)

SDWebImagePhotosPlugin is available through [Swift Package Manager](https://swift.org/package-manager).

```swift
let package = Package(
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImageSVGKitPlugin.git", from: "1.4")
    ]
)
```

#### Carthage

SDWebImageSVGKitPlugin is available through [Carthage](https://github.com/Carthage/Carthage).

```
github "SDWebImage/SDWebImageSVGKitPlugin"
```

## Usage

### Use UIImageView (render SVG as bitmap image)

To use SVG coder, you should firstly add the `SDImageSVGKCoder` to the coders manager. Then you can call the View Category method to start load SVG images.

Because SVG is a [vector image](https://en.wikipedia.org/wiki/Vector_graphics) format, which means it does not have a fixed bitmap size. However, `UIImage` or `CGImage` are all [bitmap image](https://en.wikipedia.org/wiki/Raster_graphics). For `UIImageView`, we will only parse SVG with a fixed image size (from the SVG viewPort information). But we also support you to specify a desired size during image loading using `SDWebImageContextThumbnailPixelSize` context option. And you can specify whether or not to keep aspect ratio during scale using `SDWebImageContextImagePreserveAspectRatio` context option.

+ Objective-C

```objectivec
SDImageSVGKCoder *svgCoder = [SDImageSVGKCoder sharedCoder];
[[SDImageCodersManager sharedManager] addCoder:svgCoder];
UIImageView *imageView;
// this arg is optional, if don't provide, use the viewport size instead
CGSize svgImageSize = CGSizeMake(100, 100);
[imageView sd_setImageWithURL:url placeholderImage:nil options:0 context:@{SDWebImageContextThumbnailPixelSize : @(svgImageSize)];
```

+ Swift

```swift
let svgCoder = SDImageSVGKCoder.shared
SDImageCodersManager.shared.addCoder(svgCoder)
let imageView: UIImageView
imageView.sd_setImage(with: url)
// this arg is optional, if don't provide, use the viewport size instead
let svgImageSize = CGSize(width: 100, height: 100)
imageView.sd_setImage(with: url, placeholderImage: nil, options: [], context: [.imageThumbnailPixelSize : svgImageSize])
```

### Use SVGKImageView (render SVG as vector image)

[SVGKit](https://github.com/SVGKit/SVGKit) also provide some built-in image view class for vector image loading (scale to any size without losing detail). The `SVGKLayeredImageView` && `SVGKFastImageView` are the subclass of `SVGKImageView` base class. We supports these image view class as well. You can just use the same API like normal `UIImageView`.

For the documentation about `SVGKLayeredImageView`, `SVGKFastImageView` or `SVGKImageView`, check [SVGKit](https://github.com/SVGKit/SVGKit) repo for more information.

**Note**: If you only use these image view class and don't use SVG on `UIImageView`, you don't need to register the SVG coder to coders manager. These image view loading was using the [Custom Image Class](https://github.com/rs/SDWebImage/wiki/Advanced-Usage#customization) feature of SDWebImage.

**Attention**: These built-in image view class does not works well on `UIView.contentMode` property, you need to re-scale the layer tree after image was loaded. We provide a simple out-of-box solution to support it. Set the `sd_adjustContentMode` property to `YES` then all things done.

+ Objective-C

```objectivec
SVGKImageView *imageView; // can be either `SVGKLayeredImageView` or `SVGKFastImageView`
imageView.contentMode = UIViewContentModeScaleAspectFill;
imageView.sd_adjustContentMode = YES; // make `contentMode` works
[imageView sd_setImageWithURL:url];
```

+ Swift:

```swift
let imageView: SVGKImageView // can be either `SVGKLayeredImageView` or `SVGKFastImageView`
imageView.contentMode = .aspectFill
imageView.sd_adjustContentMode = true // make `contentMode` works
imageView.sd_setImage(with: url)
```

## Export SVG data

`SDWebImageSVGKitPlugin` provide an easy way to export the SVG image generated from framework, to the original SVG data.

+ Objective-C

```objectivec
UIImage *image; // Image generated from SDWebImage framework, actually a `SDSVGKImage` instance.
NSData *imageData = [image sd_imageDataAsFormat:SDImageFormatSVG];
```

+ Swift

```swift
let image: UIImage // Image generated from SDWebImage framework, actually a `SDSVGKImage` instance.
let imageData = image.sd_imageData(as: .SVG)
```

## Screenshot

<img src="https://raw.githubusercontent.com/SDWebImage/SDWebImageSVGKitPlugin/master/Example/Screenshot/SVGDemo.png" width="300" />
<img src="https://raw.githubusercontent.com/SDWebImage/SDWebImageSVGKitPlugin/master/Example/Screenshot/SVGDemo-macOS.png" width="600" />

These SVG images are from [wikimedia](https://commons.wikimedia.org/wiki/Main_Page), you can try the demo with your own SVG image as well.

## Author

DreamPiggy

## License

SDWebImageSVGKitPlugin is available under the MIT license. See the LICENSE file for more info.


