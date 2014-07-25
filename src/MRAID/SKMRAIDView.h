//
//  SKMRAIDView.h
//  MRAID
//
//  Created by Jay Tucker on 9/13/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SKMRAIDView;
@protocol SKMRAIDServiceDelegate;

// A delegate for MRAIDView to listen for notification on ad ready or expand related events.
@protocol SKMRAIDViewDelegate <NSObject>

@optional

// These callbacks are for basic banner ad functionality.
- (void)mraidViewAdReady:(SKMRAIDView *)mraidView;
- (void)mraidViewAdFailed:(SKMRAIDView *)mraidView;
- (void)mraidViewWillExpand:(SKMRAIDView *)mraidView;
- (void)mraidViewDidClose:(SKMRAIDView *)mraidView;
- (void)mraidViewNavigate:(SKMRAIDView *)mraidView withURL:(NSURL *)url;

// This callback is to ask permission to resize an ad.
- (BOOL)mraidViewShouldResize:(SKMRAIDView *)mraidView toPosition:(CGRect)position allowOffscreen:(BOOL)allowOffscreen;

@end

@interface SKMRAIDView : UIView

@property (nonatomic, unsafe_unretained) id<SKMRAIDViewDelegate> delegate;
@property (nonatomic, unsafe_unretained) id<SKMRAIDServiceDelegate> serviceDelegate;
@property (nonatomic, unsafe_unretained) UIViewController *rootViewController;
@property (nonatomic, assign, getter = isViewable, setter = setIsViewable:) BOOL isViewable;

// IMPORTANT: This is the only valid initializer for an MRAIDView; -init and -initWithFrame: will throw exceptions
- (id)initWithFrame:(CGRect)frame
       withHtmlData:(NSString*)htmlData
        withBaseURL:(NSURL*)bsURL
  supportedFeatures:(NSArray *)features
           delegate:(id<SKMRAIDViewDelegate>)delegate
   serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
 rootViewController:(UIViewController *)rootViewController;

@end
