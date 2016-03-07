//
//  MWPhoto.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 17/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "MWRePhoto.h"
#import "MWPhotoBrowser.h"
#import "SDWebImageDecoder.h"
#import "SDWebImageManager.h"
#import "SDWebImageOperation.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface MWRePhoto () {

    BOOL _loadingInProgress;
    id <SDWebImageOperation> _webImageOperation;
        
}

- (void)imageLoadingComplete;

@end

@implementation MWRePhoto

@synthesize underlyingBeforeImage = _underlyingBeforeImage; // synth property from protocol
@synthesize underlyingAfterImage = _underlyingAfterImage; // synth property from protocol

#pragma mark - Class Methods

+ (MWRePhoto *)photoWithImage:(UIImage *)image1 image2:(UIImage*)image2 {
	return [[MWRePhoto alloc] initWithImage:image1 image2:image2];
}

+ (MWRePhoto *)photoWithURL:(NSURL *)url1 url2:(NSURL *)url2 {
	return [[MWRePhoto alloc] initWithURL:url1 url2:url2];
}

#pragma mark - Init

- (id)initWithImage:(UIImage *)image1 image2:(UIImage *)image2 {
	if ((self = [super init])) {
        _beforeImage = image1;
        _afterImage = image2;
	}
	return self;
}

- (id)initWithURL:(NSURL *)url1 url2:(NSURL *)url2 {
	if ((self = [super init])) {
		_beforeURL = [url1 copy];
        _afterURL  = [url2 copy];
	}
	return self;
}

#pragma mark - MWPhoto Protocol Methods

- (UIImage *)underlyingBeforeImage {
    return _underlyingBeforeImage;
}

- (UIImage *)underlyingAfterImage {
    return _underlyingAfterImage;
}

- (void)loadUnderlyingImageAndNotify {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    if (_loadingInProgress) return;
    _loadingInProgress = YES;
    @try {
        if (self.underlyingBeforeImage && self.underlyingAfterImage) {
            [self imageLoadingComplete];
        } else {
            [self performLoadUnderlyingImageAndNotify];
        }
    }
    @catch (NSException *exception) {
        self.underlyingBeforeImage = nil;
        self.underlyingAfterImage = nil;
        _loadingInProgress = NO;
        [self imageLoadingComplete];
    }
    @finally {
    }
}

// Set the underlyingImage
- (void)performLoadUnderlyingImageAndNotify {
    
    // Get underlying image
    if (_beforeImage && _afterImage) {
        
        // We have UIImage!
        self.underlyingBeforeImage = _beforeImage;
        self.underlyingAfterImage = _afterImage;
        [self imageLoadingComplete];
        
    } else if (_beforeURL && _afterURL) {
        
        // Check what type of url it is
        if ([[[_beforeURL scheme] lowercaseString] isEqualToString:@"assets-library"] && [[[_afterURL scheme] lowercaseString] isEqualToString:@"assets-library"]) {
            
            // Load from asset library async
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    @try {
                        ALAssetsLibrary *assetslibrary = [[ALAssetsLibrary alloc] init];
                        [assetslibrary assetForURL:_beforeURL
                                       resultBlock:^(ALAsset *asset){
                                           ALAssetRepresentation *rep = [asset defaultRepresentation];
                                           CGImageRef iref = [rep fullScreenImage];
                                           if (iref) {
                                               self.underlyingBeforeImage = [UIImage imageWithCGImage:iref];
                                           }
                                           [assetslibrary assetForURL:_afterURL
                                                          resultBlock:^(ALAsset *asset){
                                                              ALAssetRepresentation *rep = [asset defaultRepresentation];
                                                              CGImageRef iref = [rep fullScreenImage];
                                                              if (iref) {
                                                                  self.underlyingAfterImage = [UIImage imageWithCGImage:iref];
                                                              }
                                                              [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                                                          }
                                                         failureBlock:^(NSError *error) {
                                                             self.underlyingAfterImage = nil;
                                                             MWLog(@"After photo from asset library error: %@",error);
                                                             [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                                                         }];
                                       }
                                      failureBlock:^(NSError *error) {
                                          self.underlyingBeforeImage = nil;
                                          MWLog(@"Before photo from asset library error: %@",error);
                                          [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                                      }];
                        
                    } @catch (NSException *e) {
                        MWLog(@"Photo from asset library error: %@", e);
                        [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                    }
                }
            });
            
        } else if ([_beforeURL isFileReferenceURL] && [_afterURL isFileReferenceURL]) {
            
            // Load from local file async
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    @try {
                        self.underlyingBeforeImage = [UIImage imageWithContentsOfFile:_beforeURL.path];
                        self.underlyingAfterImage = [UIImage imageWithContentsOfFile:_afterURL.path];
                        if (!(_underlyingBeforeImage && _underlyingAfterImage)) {
                            MWLog(@"Error loading photos from paths: %@ and %@", _beforeURL.path, _afterURL.path);
                        }
                    } @finally {
                        [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                    }
                }
            });
            
        } else {
            
            // Load async from web (using SDWebImage)
            @try {
                SDWebImageManager *manager = [SDWebImageManager sharedManager];
                _webImageOperation = [manager downloadImageWithURL:_beforeURL
                                                           options:0
                                                          progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                                                              if (expectedSize > 0) {
                                                                  float progress = receivedSize / (float)expectedSize;
                                                                  NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                        [NSNumber numberWithFloat:progress], @"before image progress",
                                                                                        self, @"photo", nil];
                                                                  [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_PROGRESS_NOTIFICATION object:dict];
                                                              }
                                                          }
                                                         completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                                             if (error) {
                                                                 MWLog(@"SDWebImage failed to download before image: %@", error);
                                                             }
                                                             _webImageOperation = nil;
                                                             self.underlyingBeforeImage = image;
                                                             
                                                             // Load after Image
                                                             _webImageOperation = [manager downloadImageWithURL:_afterURL
                                                                                                        options:0
                                                                                                       progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                                                                                                           if (expectedSize > 0) {
                                                                                                               float progress = receivedSize / (float)expectedSize;
                                                                                                               NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                                                     [NSNumber numberWithFloat:progress], @"after image progress",
                                                                                                                                     self, @"photo", nil];
                                                                                                               [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_PROGRESS_NOTIFICATION object:dict];
                                                                                                           }
                                                                                                       }
                                                                                                      completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                                                                                          if (error) {
                                                                                                              MWLog(@"SDWebImage failed to download after image: %@", error);
                                                                                                          }
                                                                                                          _webImageOperation = nil;
                                                                                                          self.underlyingAfterImage = image;
                                                                                                          [self imageLoadingComplete];
                                                                                                      }];
                                                         }];
                
            } @catch (NSException *e) {
                MWLog(@"Photo from web: %@", e);
                _webImageOperation = nil;
                [self imageLoadingComplete];
            }
            
        }
        
    } else {
        
        // Failed - no source
        @throw [NSException exceptionWithName:@"No source" reason:nil userInfo:nil];
        
    }
}

// Release if we can get it again from path or url
- (void)unloadUnderlyingImage {
    _loadingInProgress = NO;
	self.underlyingBeforeImage = nil;
	self.underlyingAfterImage= nil;
}

- (void)imageLoadingComplete {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    // Complete so notify
    _loadingInProgress = NO;
    // Notify on next run loop
    [self performSelector:@selector(postCompleteNotification) withObject:nil afterDelay:0];
}

- (void)postCompleteNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_LOADING_DID_END_NOTIFICATION
                                                        object:self];
}

- (void)cancelAnyLoading {
    if (_webImageOperation) {
        [_webImageOperation cancel];
        _loadingInProgress = NO;
    }
}

@end
