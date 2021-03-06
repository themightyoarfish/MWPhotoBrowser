//
//  MWGridCell.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 08/10/2013.
//
//

#import <UIKit/UIKit.h>
#import "MWRePhoto.h"
#import "MWGridViewController.h"
#import "PSTCollectionView.h"

@interface MWGridCell : PSTCollectionViewCell {}

@property (nonatomic, weak) MWGridViewController *gridController;
@property (nonatomic) NSUInteger index;
@property (nonatomic) id <MWRePhoto> photo;
@property (nonatomic) BOOL selectionMode;
@property (nonatomic) BOOL isSelected;

- (void)displayImage;

@end
