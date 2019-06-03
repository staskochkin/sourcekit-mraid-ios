//
//  SKMRAIDInterstitial.h
//  MRAID
//
//  Created by Jay Tucker on 10/18/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class SKMRAIDInterstitial;
@protocol SKMRAIDServiceDelegate;
@protocol SKMRAIDDoubleClickDelegate;

// A delegate for MRAIDInterstitial to handle callbacks for the interstitial lifecycle.
@protocol SKMRAIDInterstitialDelegate <NSObject>

@optional

- (void)mraidInterstitial:(SKMRAIDInterstitial *)mraidInterstitial preloadedAd:(NSString *)preloadedAd;
- (void)mraidInterstitial:(SKMRAIDInterstitial *)mraidInterstitial didFailToPreloadAd:(NSError *)preloadError;
- (void)mraidInterstitialAdReady:(SKMRAIDInterstitial *)mraidInterstitial;
- (void)mraidInterstitialAdFailed:(SKMRAIDInterstitial *)mraidInterstitial;
- (void)mraidInterstitialWillShow:(SKMRAIDInterstitial *)mraidInterstitial;
- (void)mraidInterstitialDidHide:(SKMRAIDInterstitial *)mraidInterstitial;
- (void)mraidInterstitialNavigate:(SKMRAIDInterstitial *)mraidInterstitial withURL:(NSURL *)url;
- (void)mraidInterstitial:(SKMRAIDInterstitial *)mraidView useCustomClose:(BOOL)customClose;
- (void)mraidInterstitial:(SKMRAIDInterstitial *)mraidView intersectJsLogMessage:(NSString *)logMessage;
- (void)mraidInterstitial:(SKMRAIDInterstitial *)mraidInterstitial wasPreloadUrl:(NSURL *)url;

@end

// A class which handles interstitials and offers optional callbacks for its states and services (sms, tel, calendar, etc.)
@interface SKMRAIDInterstitial : NSObject

@property (nonatomic, weak) id<SKMRAIDInterstitialDelegate> delegate;
@property (nonatomic, weak) id<SKMRAIDServiceDelegate> serviceDelegate;
@property (nonatomic, weak) id<SKMRAIDDoubleClickDelegate> doubleClickDelegate;
@property (nonatomic, weak, setter = setRootViewController:) UIViewController *rootViewController;
@property (nonatomic, copy) UIColor *backgroundColor;
@property (nonatomic, strong) NSURL *baseURL;

// IMPORTANT: This is the only valid initializer for an MRAIDInterstitial; -init will throw an exception
- (instancetype)initWithSupportedFeatures:(NSArray *)features
                                 delegate:(id<SKMRAIDInterstitialDelegate>)delegate
                          serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
                            customScripts:(NSArray *)customScripts
                       rootViewController:(UIViewController *)rootViewController;

- (instancetype)initWithSupportedFeatures:(NSArray *)features
                                 delegate:(id<SKMRAIDInterstitialDelegate>)delegate
                          serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
                       rootViewController:(UIViewController *)rootViewController;

- (void)preloadAdFromURL:(NSURL *)url;

- (void)loadAdHTML:(NSString *)html;

- (void)loadAdHTML:(NSString *)html estimatedAdSize:(CGSize)estimatedAdSize;

- (void)cancel;

- (BOOL)isAdReady;

- (void)show;

- (void)injectJavaScript:(NSString *)js;

- (void)close;

@end
