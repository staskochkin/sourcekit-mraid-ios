//
//  SKMRAIDView.h
//  MRAID
//
//  Created by Jay Tucker on 9/13/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const kSKMRAIDErrorDomain;

typedef enum {
    MRAIDPreloadNoFillError,
    MRAIDPreloadNetworkError,
    MRAIDShowError,
    MRAIDValidationError,
    MRAIDSuspiciousCreativeError
} MRAIDError;

@class SKMRAIDView;
@protocol SKMRAIDServiceDelegate;
@protocol SKMRAIDDoubleClickDelegate;

// A delegate for MRAIDView to listen for notification on ad ready or expand related events.
@protocol SKMRAIDViewDelegate <NSObject>

@optional
// These callbacks are for basic banner ad functionality.
- (void)mraidView:(SKMRAIDView *)mraidView preloadedAd:(NSString *)preloadedAd;

- (void)mraidView:(SKMRAIDView *)mraidView didFailToPreloadAd:(NSError *)preloadError;

- (void)mraidViewAdReady:(SKMRAIDView *)mraidView;

- (void)mraidView:(SKMRAIDView *)mraidView failToLoadAdThrowError:(NSError *)error;

- (void)mraidViewWillExpand:(SKMRAIDView *)mraidView;

- (void)mraidViewDidClose:(SKMRAIDView *)mraidView;

- (void)mraidViewNavigate:(SKMRAIDView *)mraidView withURL:(NSURL *)url;

// This callback is to ask permission to resize an ad.
- (BOOL)mraidViewShouldResize:(SKMRAIDView *)mraidView toPosition:(CGRect)position allowOffscreen:(BOOL)allowOffscreen;

- (void)mraidView:(SKMRAIDView *)mraidView useCustomClose:(BOOL)customClose;

- (void)mraidView:(SKMRAIDView *)mraidView intersectJsLogMessage:(NSString *)logMessage;

- (void)mraidView:(SKMRAIDView *)mraidView wasPreloadUrl:(NSURL *)url;

@end



@interface SKMRAIDView : UIView

@property (nonatomic, weak) id<SKMRAIDViewDelegate> delegate;
@property (nonatomic, weak) id<SKMRAIDDoubleClickDelegate> doubleClickDelegate;
@property (nonatomic, weak) id<SKMRAIDServiceDelegate> serviceDelegate;
@property (nonatomic, weak, setter = setRootViewController:) UIViewController *rootViewController;
@property (nonatomic, assign) BOOL isViewable;
@property (nonatomic, strong) NSURL *baseURL;
//@property (nonatomic, assign, getter = isViewable, setter = setIsViewable:) BOOL isViewable;

// IMPORTANT: This is the only valid initializer for an MRAIDView; -init and -initWithFrame: will throw exceptions
- (instancetype)initWithFrame:(CGRect)frame
            supportedFeatures:(NSArray *)features
                     delegate:(id<SKMRAIDViewDelegate>)delegate
              serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
                customScripts:(NSArray *)customScripts
           rootViewController:(UIViewController *)rootViewController;

- (instancetype)initWithFrame:(CGRect)frame
            supportedFeatures:(NSArray *)features
                     delegate:(id<SKMRAIDViewDelegate>)delegate
              serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
           rootViewController:(UIViewController *)rootViewController;

- (void)preloadAdFromURL:(NSURL *)url;

- (void)loadAdHTML:(NSString *)html;

- (void)loadAdHTML:(NSString *)html estimatedAdSize:(CGSize)estimatedAdSize;

- (void)cancel;

- (void)close;

- (void)injectJavaScript:(NSString *)js;

@end

@interface SKMRAIDView (Private)

- (id)initWithFrame:(CGRect)frame
     asInterstitial:(BOOL)asInterstitial
  supportedFeatures:(NSArray *)features
           delegate:(id<SKMRAIDViewDelegate>)delegate
    serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
      customScripts:(NSArray *)customScripts
 rootViewController:(UIViewController *)rootViewController;

- (void)showAsInterstitial;

@end
