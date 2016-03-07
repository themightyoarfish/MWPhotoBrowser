//
//  MWPhoto.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 17/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MWRePhotoProtocol.h"

// This class models a photo/image and it's caption
// If you want to handle photos, caching, decompression
// yourself then you can simply ensure your custom data model
// conforms to MWPhotoProtocol
@interface MWRePhoto : NSObject <MWRePhoto>

@property (nonatomic, strong) NSString *caption;
@property (nonatomic, readonly) UIImage *beforeImage;
@property (nonatomic, readonly) UIImage *afterImage;
@property (nonatomic, readonly) NSURL *beforeURL;
@property (nonatomic, readonly) NSURL *afterURL;

+ (MWRePhoto *)photoWithImage:(UIImage *)image1 image2:(UIImage*)image2;
+ (MWRePhoto *)photoWithURL:(NSURL *)url1 url2:(NSURL *)url2;

- (id)initWithImage:(UIImage *)image1 image2:(UIImage *)image2;
- (id)initWithURL:(NSURL *)url1 url2:(NSURL *)url2;

@end

