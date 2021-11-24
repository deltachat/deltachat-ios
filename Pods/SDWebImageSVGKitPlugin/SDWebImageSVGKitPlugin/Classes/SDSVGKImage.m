//
//  SDSVGKImage.m
//  SDWebImageSVGPlugin
//
//  Created by DreamPiggy on 2018/10/10.
//

#import "SDSVGKImage.h"
#import "SDWebImageSVGKitDefine.h"

@interface SDSVGKImage ()

@property (nonatomic, strong, nullable) SVGKImage *SVGKImage;

@end

@implementation SDSVGKImage

- (instancetype)initWithSVGKImage:(SVGKImage *)image {
    NSParameterAssert(image);
    UIImage *posterImage = image.UIImage;
#if SD_UIKIT
    UIImageOrientation imageOrientation = posterImage.imageOrientation;
#else
    CGImagePropertyOrientation imageOrientation = kCGImagePropertyOrientationUp;
#endif
    self = [super initWithCGImage:posterImage.CGImage scale:posterImage.scale orientation:imageOrientation];
    if (self) {
        self.SVGKImage = image;
    }
    return self;
}

+ (instancetype)imageWithContentsOfFile:(NSString *)path {
    return [[self alloc] initWithContentsOfFile:path];
}

+ (instancetype)imageWithData:(NSData *)data {
    return [[self alloc] initWithData:data];
}

+ (instancetype)imageWithData:(NSData *)data scale:(CGFloat)scale {
    return [[self alloc] initWithData:data scale:scale];
}

- (instancetype)initWithData:(NSData *)data {
    return [self initWithData:data scale:1];
}

- (instancetype)initWithContentsOfFile:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [self initWithData:data];
}

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale {
    return [self initWithData:data scale:scale options:nil];
}

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale options:(SDImageCoderOptions *)options {
    SVGKImage *svgImage = [[SVGKImage alloc] initWithData:data];
    if (!svgImage) {
        return nil;
    }
    CGSize imageSize = CGSizeZero;
    
    // Check specified image size
    SDWebImageContext *context = options[SDImageCoderWebImageContext];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (context[SDWebImageContextSVGKImageSize]) {
        NSValue *sizeValue = context[SDWebImageContextSVGKImageSize];
#if SD_UIKIT
        imageSize = sizeValue.CGSizeValue;
#else
        imageSize = sizeValue.sizeValue;
#endif
    } else if (options[SDImageCoderDecodeThumbnailPixelSize]) {
        NSValue *sizeValue = options[SDImageCoderDecodeThumbnailPixelSize];
#if SD_UIKIT
        imageSize = sizeValue.CGSizeValue;
#else
        imageSize = sizeValue.sizeValue;
#endif
    }
    if (!CGSizeEqualToSize(imageSize, CGSizeZero)) {
        svgImage.size = imageSize;
    }
    return [self initWithSVGKImage:svgImage];
}

- (instancetype)initWithAnimatedCoder:(id<SDAnimatedImageCoder>)animatedCoder scale:(CGFloat)scale {
    // Does not support progressive load for SVG images at all
    return nil;
}

#pragma mark - SDAnimatedImageProvider

- (nullable NSData *)animatedImageData {
    return nil;
}

- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index {
    return 0;
}

- (nullable UIImage *)animatedImageFrameAtIndex:(NSUInteger)index {
    return nil;
}

- (NSUInteger)animatedImageFrameCount {
    return 0;
}

- (NSUInteger)animatedImageLoopCount {
    return 0;
}

@end

@implementation SDSVGKImage (Metadata)

- (BOOL)sd_isAnimated {
    return NO;
}

- (NSUInteger)sd_imageLoopCount {
    return self.animatedImageLoopCount;
}

- (void)setSd_imageLoopCount:(NSUInteger)sd_imageLoopCount {
    return;
}

- (SDImageFormat)sd_imageFormat {
    return SDImageFormatSVG;
}

- (void)setSd_imageFormat:(SDImageFormat)sd_imageFormat {
    return;
}

- (BOOL)sd_isVector {
    return YES;
}

@end
