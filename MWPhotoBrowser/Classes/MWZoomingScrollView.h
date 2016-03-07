//
//  ZoomingScrollView.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MWRePhotoProtocol.h"
#import "MWTapDetectingImageView.h"
#import "MWTapDetectingView.h"

@class MWPhotoBrowser, MWRePhoto, MWCaptionView;

@interface MWZoomingScrollView : UIScrollView <UIScrollViewDelegate, MWTapDetectingImageViewDelegate, MWTapDetectingViewDelegate> {

}

@property () NSUInteger index;
@property (nonatomic) id <MWRePhoto> rePhoto;
@property (nonatomic, weak) MWCaptionView *captionView;
@property (nonatomic, weak) UIButton *selectedButton;

- (id)initWithPhotoBrowser:(MWPhotoBrowser *)browser;
- (void)displayImage;
- (void)displayImageFailure;
- (void)setMaxMinZoomScalesForCurrentBounds;
- (void)prepareForReuse;

@end
