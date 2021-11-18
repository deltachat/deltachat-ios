//
//  SVGKImageView+WebCache.m
//  SDWebImageSVGPlugin
//
//  Created by DreamPiggy on 2018/10/10.
//

#import "SVGKImageView+WebCache.h"
#import "SDSVGKImage.h"
#import <objc/runtime.h>

@implementation SVGKImageView (WebCache)

- (void)setSd_adjustContentMode:(BOOL)sd_adjustContentMode {
    objc_setAssociatedObject(self, @selector(sd_adjustContentMode), @(sd_adjustContentMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)sd_adjustContentMode {
    NSNumber *value = objc_getAssociatedObject(self, @selector(sd_adjustContentMode));
    return value.boolValue;
}

- (void)sd_setImageWithURL:(nullable NSURL *)url {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)sd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)sd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(SDWebImageOptions)options {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)sd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(SDWebImageOptions)options context:(nullable SDWebImageContext *)context {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)sd_setImageWithURL:(nullable NSURL *)url completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)sd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)sd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(SDWebImageOptions)options completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)sd_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(SDWebImageOptions)options progress:(nullable SDImageLoaderProgressBlock)progressBlock completed:(nullable SDExternalCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)sd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(SDWebImageOptions)options
                   context:(nullable SDWebImageContext *)context
                  progress:(nullable SDImageLoaderProgressBlock)progressBlock
                 completed:(nullable SDExternalCompletionBlock)completedBlock {
    Class imageClass = [SDSVGKImage class];
    SDWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[SDWebImageContextAnimatedImageClass] = imageClass;
    __weak typeof(self)weakSelf = self;
    [self sd_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           __strong typeof(weakSelf)strongSelf = weakSelf;
                           if (!strongSelf) {
                               return;
                           }
                           SVGKImage *svgImage;
                           if ([image isKindOfClass:[SDSVGKImage class]]) {
                               svgImage = ((SDSVGKImage *)image).SVGKImage;
                           }
                           if (svgImage) {
#if SD_UIKIT
                               if (self.sd_adjustContentMode) {
                                   SDAdjustSVGContentMode(svgImage, strongSelf.contentMode, strongSelf.bounds.size);
                               }
#endif
                               strongSelf.image = svgImage;
                           } else {
                               strongSelf.image = nil;
                           }
                       }
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

@end
