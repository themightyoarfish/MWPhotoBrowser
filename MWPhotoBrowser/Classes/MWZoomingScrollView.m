//
//  ZoomingScrollView.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "MWCommon.h"
#import "MWZoomingScrollView.h"
#import "MWPhotoBrowser.h"
#import "MWRePhoto.h"
#import "DACircularProgressView.h"
#import "MWPhotoBrowserPrivate.h"

// Private methods and properties
@interface MWZoomingScrollView () {
    
    MWPhotoBrowser __weak *_photoBrowser;
	MWTapDetectingView *_tapView; // for background taps
	MWTapDetectingImageView *_beforePhotoImageView;
	MWTapDetectingImageView *_afterPhotoImageView;
    UIView* _imageContainer;
	DACircularProgressView *_loadingIndicator;
    UIImageView *_loadingError;
    UISlider* _slider;
}

@end

@implementation MWZoomingScrollView

- (id)initWithPhotoBrowser:(MWPhotoBrowser *)browser {
    if ((self = [super init])) {
        
        // Setup
        _index = NSUIntegerMax;
        _photoBrowser = browser;
        
		// Tap view for background
		_tapView = [[MWTapDetectingView alloc] initWithFrame:self.bounds];
		_tapView.tapDelegate = self;
		_tapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_tapView.backgroundColor = [UIColor blackColor];
		[self addSubview:_tapView];
		
		// Image views
        _imageContainer = [UIView new];
		_beforePhotoImageView = [[MWTapDetectingImageView alloc] initWithFrame:CGRectZero];
		_beforePhotoImageView.tapDelegate = self;
		_beforePhotoImageView.contentMode = UIViewContentModeCenter;
		_beforePhotoImageView.backgroundColor = [UIColor blackColor];
		[_imageContainer addSubview:_beforePhotoImageView];
        
        _afterPhotoImageView = [[MWTapDetectingImageView alloc] initWithFrame:CGRectZero];
        _afterPhotoImageView.tapDelegate = self;
        _afterPhotoImageView.contentMode = UIViewContentModeCenter;
        _afterPhotoImageView.backgroundColor = [UIColor blackColor];
        [_imageContainer addSubview:_afterPhotoImageView];
        [self addSubview:_imageContainer];
        
		// Loading indicator
		_loadingIndicator = [[DACircularProgressView alloc] initWithFrame:CGRectMake(140.0f, 30.0f, 40.0f, 40.0f)];
        _loadingIndicator.userInteractionEnabled = NO;
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
            _loadingIndicator.thicknessRatio = 0.1;
            _loadingIndicator.roundedCorners = NO;
        } else {
            _loadingIndicator.thicknessRatio = 0.2;
            _loadingIndicator.roundedCorners = YES;
        }
		_loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
		[self addSubview:_loadingIndicator];
        
        UISlider* slider = [[UISlider alloc] initWithFrame:CGRectZero];
        [self addSubview:slider];
        [self bringSubviewToFront:slider];

        // Listen progress notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(setProgressFromNotification:)
                                                     name:MWPHOTO_PROGRESS_NOTIFICATION
                                                   object:nil];
        
		// Setup
		self.backgroundColor = [UIColor blackColor];
		self.delegate = self;
		self.showsHorizontalScrollIndicator = NO;
		self.showsVerticalScrollIndicator = NO;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)prepareForReuse {
    [self hideImageFailure];
    self.rePhoto = nil;
    self.captionView = nil;
    self.selectedButton = nil;
    _beforePhotoImageView.image = nil;
    _afterPhotoImageView.image = nil;
    _index = NSUIntegerMax;
}

#pragma mark - Image

- (void)setRePhoto:(id<MWRePhoto>)photo {
    // Cancel any loading on old photo
    if (_rePhoto && photo == nil) {
        if ([_rePhoto respondsToSelector:@selector(cancelAnyLoading)]) {
            [_rePhoto cancelAnyLoading];
        }
    }
    _rePhoto = photo;

    NSArray* imgs = [_photoBrowser imagesForRePhoto:_rePhoto];
    if (imgs) {
        [self displayImage];
    } else {
        // Will be loading so show loading
        [self showLoadingIndicator];
    }
}

// Get and display image
- (void)displayImage {
	if (_rePhoto && (_beforePhotoImageView.image == nil || _afterPhotoImageView.image == nil)) {
		
		// Reset
		self.maximumZoomScale = 1;
		self.minimumZoomScale = 1;
		self.zoomScale = 1;
		self.contentSize = CGSizeMake(0, 0);
		
		// Get images from browser as it handles ordering of fetching
        NSArray* imgs = [_photoBrowser imagesForRePhoto:_rePhoto];
		if (imgs) {
			
			// Hide indicator
			[self hideLoadingIndicator];
			
			// Set image
			UIImage* beforeImg = _beforePhotoImageView.image = imgs[0];
			_beforePhotoImageView.hidden = NO;
            UIImage* afterImg = _afterPhotoImageView.image = imgs[1];
            _afterPhotoImageView.hidden = NO;
			
			// Setup photo frame
			CGRect photoImageViewFrame;
			photoImageViewFrame.origin = CGPointZero;
			photoImageViewFrame.size = CGSizeMake(MAX(beforeImg.size.width, afterImg.size.width), MAX(beforeImg.size.height, afterImg.size.height));
			_beforePhotoImageView.frame = photoImageViewFrame;
			_afterPhotoImageView.frame = photoImageViewFrame;
			self.contentSize = photoImageViewFrame.size;
            _imageContainer.frame = photoImageViewFrame;

			// Set zoom to minimum zoom
			[self setMaxMinZoomScalesForCurrentBounds];
			
		} else {
			
			// Failed no image
            [self displayImageFailure];
			
		}
		[self setNeedsLayout];
	}
}

// Image failed so just show black!
- (void)displayImageFailure {
    [self hideLoadingIndicator];
    _beforePhotoImageView.image = nil;
    if (!_loadingError) {
        _loadingError = [UIImageView new];
        _loadingError.image = [UIImage imageNamed:@"MWPhotoBrowser.bundle/images/ImageError.png"];
        _loadingError.userInteractionEnabled = NO;
		_loadingError.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
        [_loadingError sizeToFit];
        [self addSubview:_loadingError];
    }
    _loadingError.frame = CGRectMake(floorf((self.bounds.size.width - _loadingError.frame.size.width) / 2.),
                                     floorf((self.bounds.size.height - _loadingError.frame.size.height) / 2),
                                     _loadingError.frame.size.width,
                                     _loadingError.frame.size.height);
}

- (void)hideImageFailure {
    if (_loadingError) {
        [_loadingError removeFromSuperview];
        _loadingError = nil;
    }
}

#pragma mark - Loading Progress

- (void)setProgressFromNotification:(NSNotification *)notification {
    NSDictionary *dict = [notification object];
    id <MWRePhoto> photoWithProgress = [dict objectForKey:@"photo"];
    if (photoWithProgress == self.rePhoto) {
        float progress = [[dict valueForKey:@"progress"] floatValue];
        _loadingIndicator.progress = MAX(MIN(1, progress), 0);
    }
}

- (void)hideLoadingIndicator {
    _loadingIndicator.hidden = YES;
}

- (void)showLoadingIndicator {
    self.zoomScale = 0;
    self.minimumZoomScale = 0;
    self.maximumZoomScale = 0;
    _loadingIndicator.progress = 0;
    _loadingIndicator.hidden = NO;
    [self hideImageFailure];
}

#pragma mark - Setup

- (CGFloat)initialZoomScaleWithMinScale {
    CGFloat zoomScale = self.minimumZoomScale;
    if (_beforePhotoImageView && _afterPhotoImageView && _photoBrowser.zoomPhotosToFill) {
        CGSize boundsSize = self.bounds.size;
        UIImage* beforeImg = _beforePhotoImageView.image;
        UIImage* afterImg = _afterPhotoImageView.image;
        CGSize imageSize = CGSizeMake(MAX(beforeImg.size.width, afterImg.size.width), MAX(beforeImg.size.height, afterImg.size.height));
        _imageContainer.frame = CGRectMake(0, 0, imageSize.width, imageSize.height);
        
        CGFloat boundsAR = boundsSize.width / boundsSize.height;
        CGFloat imageAR = imageSize.width / imageSize.height;
        CGFloat xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
        CGFloat yScale = boundsSize.height / imageSize.height;  // the scale needed to perfectly fit the image height-wise
        self.minimumZoomScale = MIN(self.minimumZoomScale, MIN(xScale, yScale));
        // Zooms standard portrait images on a 3.5in screen but not on a 4in screen.
        if (ABS(boundsAR - imageAR) < 0.17) {
            zoomScale = MAX(xScale, yScale);
            // Ensure we don't zoom in or out too far, just in case
            zoomScale = MIN(MAX(self.minimumZoomScale, zoomScale), self.maximumZoomScale);
        }
    }
    
    return zoomScale;
}

- (void)setMaxMinZoomScalesForCurrentBounds {
	
	// Reset
	self.maximumZoomScale = 1;
	self.minimumZoomScale = 1;
	self.zoomScale = 1;
	
	// Bail if no image
	if (_beforePhotoImageView.image == nil || _afterPhotoImageView == nil) return;
    
	// Reset position
	_beforePhotoImageView.frame = CGRectMake(0, 0, _beforePhotoImageView.frame.size.width, _beforePhotoImageView.frame.size.height);
	_afterPhotoImageView.frame = CGRectMake(0, 0, _afterPhotoImageView.frame.size.width, _afterPhotoImageView.frame.size.height);
	
	// Sizes
    CGSize boundsSize = self.bounds.size;
    CGSize imageSize = _imageContainer.frame.size;

    // Calculate Min
    CGFloat xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
    CGFloat yScale = boundsSize.height / imageSize.height;  // the scale needed to perfectly fit the image height-wise
    CGFloat minScale = MIN(xScale, yScale);                 // use minimum of these to allow the image to become fully visible

    // Calculate Max
	CGFloat maxScale = 3;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // Let them go a bit bigger on a bigger screen!
        maxScale = 2;
    }

    // Image is smaller than screen so no zooming!
	if (xScale >= 1 && yScale >= 1) {
		minScale = 1.0;
	}
	
	// Set min/max zoom
	self.maximumZoomScale = maxScale;
	self.minimumZoomScale = minScale;
    
    // Initial zoom
    self.zoomScale = [self initialZoomScaleWithMinScale];

    // If we're zooming to fill then centralise
    if (self.zoomScale != minScale) {
        // Centralise
        self.contentOffset = CGPointMake((imageSize.width * self.zoomScale - boundsSize.width) / 2.0,
                                         (imageSize.height * self.zoomScale - boundsSize.height) / 2.0);
        // Disable scrolling initially until the first pinch to fix issues with swiping on an initally zoomed in photo
        self.scrollEnabled = NO;
    }
    
    // Layout
	[self setNeedsLayout];
    
}

#pragma mark - Layout

- (void)layoutSubviews {
	
//    float sliderWidth = self.bounds.size.width * 0.7;
//    float sliderHeight = 100;
//    _slider.frame = CGRectMake(self.bounds.size.width - 0.5 * sliderWidth, self.bounds.size.height * 0.1, sliderWidth, sliderHeight);
//    
	// Update tap view frame
	_tapView.frame = self.bounds;
	
	// Position indicators (centre does not seem to work!)
	if (!_loadingIndicator.hidden)
        _loadingIndicator.frame = CGRectMake(floorf((self.bounds.size.width - _loadingIndicator.frame.size.width) / 2.),
                                         floorf((self.bounds.size.height - _loadingIndicator.frame.size.height) / 2),
                                         _loadingIndicator.frame.size.width,
                                         _loadingIndicator.frame.size.height);
	if (_loadingError)
        _loadingError.frame = CGRectMake(floorf((self.bounds.size.width - _loadingError.frame.size.width) / 2.),
                                         floorf((self.bounds.size.height - _loadingError.frame.size.height) / 2),
                                         _loadingError.frame.size.width,
                                         _loadingError.frame.size.height);

	// Super
	[super layoutSubviews];
	
    // Center the image as it becomes smaller than the size of the screen
    CGSize boundsSize = self.bounds.size;
    
    CGRect frameToCenter = _imageContainer.frame;
    
    // Horizontally
    if (frameToCenter.size.width < boundsSize.width) {
        frameToCenter.origin.x = floorf((boundsSize.width - frameToCenter.size.width) / 2.0);
	} else {
        frameToCenter.origin.x = 0;
	}
    
    // Vertically
    if (frameToCenter.size.height < boundsSize.height) {
        frameToCenter.origin.y = floorf((boundsSize.height - frameToCenter.size.height) / 2.0);
	} else {
        frameToCenter.origin.y = 0;
	}
    
	// Center
	if (!CGRectEqualToRect(_imageContainer.frame, frameToCenter))
		_imageContainer.frame = frameToCenter;
	
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return _imageContainer;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[_photoBrowser cancelControlHiding];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    self.scrollEnabled = YES; // reset
	[_photoBrowser cancelControlHiding];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	[_photoBrowser hideControlsAfterDelay];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Tap Detection

- (void)handleSingleTap:(CGPoint)touchPoint {
	[_photoBrowser performSelector:@selector(toggleControls) withObject:nil afterDelay:0.2];
}

- (void)handleDoubleTap:(CGPoint)touchPoint {
	
	// Cancel any single tap handling
	[NSObject cancelPreviousPerformRequestsWithTarget:_photoBrowser];
	
	// Zoom
	if (self.zoomScale != self.minimumZoomScale && self.zoomScale != [self initialZoomScaleWithMinScale]) {
		
		// Zoom out
		[self setZoomScale:self.minimumZoomScale animated:YES];
		
	} else {
		
		// Zoom in to twice the size
        CGFloat newZoomScale = ((self.maximumZoomScale + self.minimumZoomScale) / 2);
        CGFloat xsize = self.bounds.size.width / newZoomScale;
        CGFloat ysize = self.bounds.size.height / newZoomScale;
        [self zoomToRect:CGRectMake(touchPoint.x - xsize/2, touchPoint.y - ysize/2, xsize, ysize) animated:YES];

	}
	
	// Delay controls
	[_photoBrowser hideControlsAfterDelay];
	
}

// Image View
- (void)imageView:(UIImageView *)imageView singleTapDetected:(UITouch *)touch { 
    [self handleSingleTap:[touch locationInView:imageView]];
}
- (void)imageView:(UIImageView *)imageView doubleTapDetected:(UITouch *)touch {
    [self handleDoubleTap:[touch locationInView:imageView]];
}

// Background View
- (void)view:(UIView *)view singleTapDetected:(UITouch *)touch {
    // Translate touch location to image view location
    CGFloat touchX = [touch locationInView:view].x;
    CGFloat touchY = [touch locationInView:view].y;
    touchX *= 1/self.zoomScale;
    touchY *= 1/self.zoomScale;
    touchX += self.contentOffset.x;
    touchY += self.contentOffset.y;
    [self handleSingleTap:CGPointMake(touchX, touchY)];
}
- (void)view:(UIView *)view doubleTapDetected:(UITouch *)touch {
    // Translate touch location to image view location
    CGFloat touchX = [touch locationInView:view].x;
    CGFloat touchY = [touch locationInView:view].y;
    touchX *= 1/self.zoomScale;
    touchY *= 1/self.zoomScale;
    touchX += self.contentOffset.x;
    touchY += self.contentOffset.y;
    [self handleDoubleTap:CGPointMake(touchX, touchY)];
}

@end
