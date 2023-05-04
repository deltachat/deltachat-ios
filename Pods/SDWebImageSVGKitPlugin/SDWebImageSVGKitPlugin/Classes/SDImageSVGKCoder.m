//
//  SDImageSVGKCoder.m
//  SDWebImageSVGPlugin
//
//  Created by DreamPiggy on 2018/9/27.
//

#import "SDImageSVGKCoder.h"
#import "SDSVGKImage.h"
#import "SDWebImageSVGKitDefine.h"
#if __has_include(<SVGKit/SVGKit.h>)
#import <SVGKit/SVGKit.h>
#else
@import SVGKit;
#endif
#define kSVGTagEnd @"</svg>"

@implementation SDImageSVGKCoder

+ (SDImageSVGKCoder *)sharedCoder {
    static dispatch_once_t onceToken;
    static SDImageSVGKCoder *coder;
    dispatch_once(&onceToken, ^{
        coder = [[SDImageSVGKCoder alloc] init];
    });
    return coder;
}

#pragma mark - Decode

- (BOOL)canDecodeFromData:(NSData *)data {
    return [self.class isSVGFormatForData:data];
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(SDImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    // Parse SVG
    SVGKImage *svgImage = [[SVGKImage alloc] initWithData:data];
    if (!svgImage) {
        return nil;
    }
    
    CGSize imageSize = CGSizeZero;
    BOOL preserveAspectRatio = YES;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Parse args
    SDWebImageContext *context = options[SDImageCoderWebImageContext];
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
    if (context[SDWebImageContextSVGKImagePreserveAspectRatio]) {
        preserveAspectRatio = [context[SDWebImageContextSVGKImagePreserveAspectRatio] boolValue];
    } else if (options[SDImageCoderDecodePreserveAspectRatio]) {
        preserveAspectRatio = [options[SDImageCoderDecodePreserveAspectRatio] boolValue];
    }
#pragma clang diagnostic pop
    
    if (!CGSizeEqualToSize(imageSize, CGSizeZero)) {
        if (preserveAspectRatio) {
            [svgImage scaleToFitInside:imageSize];
        } else {
            svgImage.size = imageSize;
        }
    }
    
    UIImage *image = svgImage.UIImage;
    if (!image) {
        return nil;
    }
    
    // SVG is vector image, so no need scale factor
    image.sd_imageFormat = SDImageFormatSVG;
    
    return image;
}

#pragma mark - Encode

- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    return format == SDImageFormatSVG;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(SDImageFormat)format options:(SDImageCoderOptions *)options {
    // Only support SVGKImage wrapper
    if (![image isKindOfClass:SDSVGKImage.class]) {
        return nil;
    }
    SVGKImage *svgImage = ((SDSVGKImage *)image).SVGKImage;
    if (!svgImage) {
        return nil;
    }
    SVGKSource *source = svgImage.source;
    // Should be NSData type source
    if (![source isKindOfClass:SVGKSourceNSData.class]) {
        return nil;
    }
    return ((SVGKSourceNSData *)source).rawData;
}

#pragma mark - Helper

+ (BOOL)isSVGFormatForData:(NSData *)data {
    if (!data) {
        return NO;
    }
    if (data.length <= 100) {
        return NO;
    }
    // Check end with SVG tag
    NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(data.length - 100, 100)] encoding:NSASCIIStringEncoding];
    if (![testString containsString:kSVGTagEnd]) {
        return NO;
    }
    return YES;
}

@end
