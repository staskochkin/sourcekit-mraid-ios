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

// A delegate for MRAIDInterstitial to handle callbacks for the interstitial lifecycle.
@protocol SKMRAIDInterstitialDelegate <NSObject>

@optional

- (void)mraidInterstitialAdReady:(SKMRAIDInterstitial *)mraidInterstitial;
- (void)mraidInterstitialAdFailed:(SKMRAIDInterstitial *)mraidInterstitial;
- (void)mraidInterstitialWillShow:(SKMRAIDInterstitial *)mraidInterstitial;
- (void)mraidInterstitialDidHide:(SKMRAIDInterstitial *)mraidInterstitial;
- (void)mraidInterstitialNavigate:(SKMRAIDInterstitial *)mraidInterstitial withURL:(NSURL *)url;

@end

// A class which handles interstitials and offers optional callbacks for its states and services (sms, tel, calendar, etc.)
@interface SKMRAIDInterstitial : NSObject

@property (nonatomic, unsafe_unretained) id<SKMRAIDInterstitialDelegate> delegate;
@property (nonatomic, unsafe_unretained) id<SKMRAIDServiceDelegate> serviceDelegate;
@property (nonatomic, unsafe_unretained, setter = setRootViewController:) UIViewController *rootViewController;
@property (nonatomic, assign, getter = isViewable, setter = setIsViewable:) BOOL isViewable;

// IMPORTANT: This is the only valid initializer for an MRAIDInterstitial; -init will throw an exception
- (id)initWithSupportedFeatures:(NSArray *)features
                   withHtmlData:(NSString*)htmlData
                    withBaseURL:(NSURL*)bsURL
                       delegate:(id<SKMRAIDInterstitialDelegate>)delegate
               serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
             rootViewController:(UIViewController *)rootViewController;
- (BOOL)isAdReady;
- (void)show;

@end
