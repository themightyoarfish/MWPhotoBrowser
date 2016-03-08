//
//  MWTapDetectingImageView.h
//
//  Created by Michael Waterfall on 04/11/2009.
//  Copyright 2009 d3i. All rights reserved.
//
//  Modified by Rasmus Diederichsen
//  rdiederichse at uos.de
//

#import <Foundation/Foundation.h>
#import "MaskableUIImageView.h"

@protocol MWTapDetectingImageViewDelegate;

@interface MWTapDetectingImageView : MaskableUIImageView {}

@property (nonatomic, weak) id <MWTapDetectingImageViewDelegate> tapDelegate;

@end

@protocol MWTapDetectingImageViewDelegate <NSObject>

@optional

- (void)imageView:(UIImageView *)imageView singleTapDetected:(UITouch *)touch;
- (void)imageView:(UIImageView *)imageView doubleTapDetected:(UITouch *)touch;
- (void)imageView:(UIImageView *)imageView tripleTapDetected:(UITouch *)touch;

@end