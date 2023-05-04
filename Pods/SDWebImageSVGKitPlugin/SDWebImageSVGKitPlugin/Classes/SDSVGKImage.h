//
//  SDSVGKImage.h
//  SDWebImageSVGPlugin
//
//  Created by DreamPiggy on 2018/10/10.
//

#if __has_include(<SDWebImage/SDWebImage.h>)
#import <SDWebImage/SDWebImage.h>
#else
@import SDWebImage;
#endif
#if __has_include(<SVGKit/SVGKit.h>)
#import <SVGKit/SVGKit.h>
#else
@import SVGKit;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SDSVGKImage : UIImage <SDAnimatedImage>

@property (nonatomic, strong, nullable, readonly) SVGKImage *SVGKImage;

/**
 Create the wrapper with specify `SVGKImage` instance. The instance should be nonnull.
 This is a convenience method for some use cases, for example, create a placeholder with `SVGKImage`.
 
 @param image The `SVGKImage` instance
 @return An initialized object
 */
- (nonnull instancetype)initWithSVGKImage:(nonnull SVGKImage *)image;

// This class override these methods from UIImage
// You should use these methods to create a new SVG image. Use other methods just call super instead.
+ (nullable instancetype)imageWithContentsOfFile:(nonnull NSString *)path;
+ (nullable instancetype)imageWithData:(nonnull NSData *)data;
+ (nullable instancetype)imageWithData:(nonnull NSData *)data scale:(CGFloat)scale;
- (nullable instancetype)initWithContentsOfFile:(nonnull NSString *)path;
- (nullable instancetype)initWithData:(nonnull NSData *)data;
- (nullable instancetype)initWithData:(nonnull NSData *)data scale:(CGFloat)scale;

@end

NS_ASSUME_NONNULL_END
