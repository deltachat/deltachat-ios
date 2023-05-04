//
//  SDWebImageSVGKitDefine.m
//  SDWebImageSVGPlugin
//
//  Created by DreamPiggy on 2018/10/11.
//

#import "SDWebImageSVGKitDefine.h"
#if __has_include(<SVGKit/SVGKit.h>)
#import <SVGKit/SVGKit.h>
#else
@import SVGKit;
#endif
#if SD_UIKIT
void SDAdjustSVGContentMode(SVGKImage * svgImage, UIViewContentMode contentMode, CGSize viewSize) {
    NSCParameterAssert(svgImage);
    if (!svgImage.hasSize) {
        // `SVGKImage` does not has size, specify the content size, earily return
        svgImage.size = viewSize;
        return;
    }
    CGSize imageSize = svgImage.size;
    if (imageSize.height == 0 || viewSize.height == 0) {
        return;
    }
    CGFloat wScale = viewSize.width / imageSize.width;
    CGFloat hScale = viewSize.height / imageSize.height;
    CGFloat imageAspect = imageSize.width / imageSize.height;
    CGFloat viewAspect = viewSize.width / viewSize.height;
    CGFloat xPosition;
    CGFloat yPosition;
    
    // Geometry calculation
    switch (contentMode) {
        case UIViewContentModeScaleToFill: {
            svgImage.size = viewSize;
        }
            break;
        case UIViewContentModeScaleAspectFit: {
            CGFloat scale;
            if (imageAspect > viewAspect) {
                // scale width
                scale = wScale;
            } else {
                // scale height
                scale = hScale;
            }
            CGSize targetSize = CGSizeApplyAffineTransform(imageSize, CGAffineTransformMakeScale(scale, scale));
            if (imageAspect > viewAspect) {
                // need center y as well
                xPosition = 0;
                yPosition = ABS(targetSize.height - viewSize.height) / 2;
            } else {
                // need center x as well
                xPosition = ABS(targetSize.width - viewSize.width) / 2;
                yPosition = 0;
            }
            svgImage.size = targetSize;
            svgImage.DOMTree.viewport = SVGRectMake(xPosition, yPosition, targetSize.width, targetSize.height);
            // masksToBounds to clip the sublayer which beyond the viewport to match `UIImageView` behavior
            svgImage.CALayerTree.masksToBounds = YES;
        }
            break;
        case UIViewContentModeScaleAspectFill: {
            CGFloat scale;
            if (imageAspect < viewAspect) {
                // scale width
                scale = wScale;
            } else {
                // scale height
                scale = hScale;
            }
            CGSize targetSize = CGSizeApplyAffineTransform(imageSize, CGAffineTransformMakeScale(scale, scale));
            if (imageAspect < viewAspect) {
                // need center y as well
                xPosition = 0;
                yPosition = ABS(targetSize.height - viewSize.height) / 2;
            } else {
                // need center x as well
                xPosition = ABS(targetSize.width - viewSize.width) / 2;
                yPosition = 0;
            }
            svgImage.size = targetSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeTop: {
            xPosition = (imageSize.width - viewSize.width) / 2;
            yPosition = 0;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeTopLeft: {
            xPosition = 0;
            yPosition = 0;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeTopRight: {
            xPosition = imageSize.width - viewSize.width;
            yPosition = 0;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeCenter: {
            xPosition = (imageSize.width - viewSize.width) / 2;
            yPosition = (imageSize.height - viewSize.height) / 2;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeLeft: {
            xPosition = 0;
            yPosition = (imageSize.height - viewSize.height) / 2;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeRight: {
            xPosition = imageSize.width - viewSize.width;
            yPosition = (imageSize.height - viewSize.height) / 2;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeBottom: {
            xPosition = (imageSize.width - viewSize.width) / 2;
            yPosition = imageSize.height - viewSize.height;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeBottomLeft: {
            xPosition = 0;
            yPosition = imageSize.height - viewSize.height;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeBottomRight: {
            xPosition = imageSize.width - viewSize.width;
            yPosition = imageSize.height - viewSize.height;
            svgImage.size = imageSize;
            svgImage.DOMTree.viewBox = SVGRectMake(xPosition, yPosition, imageSize.width, imageSize.height);
        }
            break;
        case UIViewContentModeRedraw: {
            svgImage.CALayerTree.needsDisplayOnBoundsChange = YES;
        }
            break;
    }
}
#endif

SDWebImageContextOption _Nonnull const SDWebImageContextSVGKImageSize = @"svgkImageSize";
SDWebImageContextOption _Nonnull const SDWebImageContextSVGKImagePreserveAspectRatio = @"svgkImagePreserveAspectRatio";
