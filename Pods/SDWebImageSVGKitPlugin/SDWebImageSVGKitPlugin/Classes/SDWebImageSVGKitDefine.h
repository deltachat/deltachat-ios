//
//  SDWebImageSVGKitDefine.h
//  SDWebImageSVGPlugin
//
//  Created by DreamPiggy on 2018/10/11.
//

#if __has_include(<SDWebImage/SDWebImage.h>)
#import <SDWebImage/SDWebImage.h>
#else
@import SDWebImage;
#endif

@class SVGKImage;

#if SD_UIKIT
/**
 Adjust `SVGKImage`'s viewPort && viewBox to match the specify `contentMode` of view size.
 @note Though this util method can be used outside this framework. For simple SVG image loading, it's recommaned to use `sd_adjustContentMode` property on `SVGKImageView+WebCache`.

 @param image `SVGKImage` instance, should not be nil.
 @param contentMode The contentMode to be applied. All possible contentMode are supported.
 @param viewSize Target view size, typically specify the `view.bounds.size`.
 */
FOUNDATION_EXPORT void SDAdjustSVGContentMode(SVGKImage * __nonnull image, UIViewContentMode contentMode, CGSize viewSize);
#endif

/**
 A CGSize raw value which specify the desired SVG image size during image loading. Because vector image like SVG format, may not contains a fixed size, or you want to get a larger size bitmap representation UIImage. (NSValue)
 If you don't provide this value, use viewBox size of SVG for default value;
 */
FOUNDATION_EXPORT SDWebImageContextOption _Nonnull const SDWebImageContextSVGKImageSize __attribute__((deprecated("Use the new context option (for WebCache category), or coder option (for SDImageCoder protocol) instead", "SDWebImageContextImageThumbnailPixelSize")));

/**
 A BOOL value which specify the whether SVG image should keep aspect ratio during image loading. Because when you specify image size via `SDWebImageContextSVGKImageSize`, we need to know whether to keep aspect ratio or not when image size aspect ratio is not equal to SVG viewBox size aspect ratio. (NSNumber)
 If you don't provide this value, use YES for default value.
 */
FOUNDATION_EXPORT SDWebImageContextOption _Nonnull const SDWebImageContextSVGKImagePreserveAspectRatio __attribute__((deprecated("Use the new context option (for WebCache category), or coder option (for SDImageCoder protocol) instead", "SDWebImageContextImagePreserveAspectRatio")));
