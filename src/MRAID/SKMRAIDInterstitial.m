//
//  SKMRAIDInterstitial.m
//  MRAID
//
//  Created by Jay Tucker on 10/18/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import "SKMRAIDInterstitial.h"
#import "SKMRAIDView.h"
#import "SKMRAIDServiceDelegate.h"

@interface SKMRAIDInterstitial () <SKMRAIDViewDelegate, SKMRAIDServiceDelegate>
{
    BOOL isReady;
    SKMRAIDView *mraidView;
    NSArray* supportedFeatures;
}

@end

@interface SKMRAIDView()

- (id)initWithFrame:(CGRect)frame
       withHtmlData:(NSString*)htmlData
        withBaseURL:(NSURL*)bsURL
     asInterstitial:(BOOL)isInter
  supportedFeatures:(NSArray *)features
           delegate:(id<SKMRAIDViewDelegate>)delegate
   serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
 rootViewController:(UIViewController *)rootViewController;

@end

@implementation SKMRAIDInterstitial

@synthesize isViewable=_isViewable;
@synthesize rootViewController=_rootViewController;

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class MRAIDInterstitial"
                                 userInfo:nil];
    return nil;
}

- (void) dealloc
{
    mraidView = nil;
    supportedFeatures = nil;
}

// designated initializer
- (id)initWithSupportedFeatures:(NSArray *)features
                   withHtmlData:(NSString*)htmlData
                    withBaseURL:(NSURL*)bsURL
                       delegate:(id<SKMRAIDInterstitialDelegate>)delegate
               serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
             rootViewController:(UIViewController *)rootViewController
{
    self = [super init];
    if (self) {
        supportedFeatures = features;
        _delegate = delegate;
        _serviceDelegate = serviceDelegate;
        _rootViewController = rootViewController;
        
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        mraidView = [[SKMRAIDView alloc] initWithFrame:screenRect
                                        withHtmlData:htmlData
                                         withBaseURL:bsURL
                                      asInterstitial:YES
                                   supportedFeatures:supportedFeatures
                                            delegate:self
                                    serviceDelegate:self
                                  rootViewController:self.rootViewController];
        _isViewable = NO;
        isReady = NO;
    }
    return self;
}

- (BOOL)isAdReady
{
    return isReady;
}

- (void)show
{
    if (!isReady) return;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [mraidView performSelector:@selector(showAsInterstitial)];
#pragma clang diagnostic pop
}

-(void)setIsViewable:(BOOL)newIsViewable
{
    mraidView.isViewable=newIsViewable;
}

-(BOOL)isViewable
{
    return _isViewable;
}

- (void)setRootViewController:(UIViewController *)newRootViewController
{
    mraidView.rootViewController = newRootViewController;
}

-(void)setBackgroundColor:(UIColor *)backgroundColor
{
    mraidView.backgroundColor = backgroundColor;
}

#pragma mark - MRAIDViewDelegate

- (void)mraidViewAdReady:(SKMRAIDView *)mraidView
{
    isReady = YES;
    if ([self.delegate respondsToSelector:@selector(mraidInterstitialAdReady:)]) {
        [self.delegate mraidInterstitialAdReady:self];
    }
}

- (void)mraidViewAdFailed:(SKMRAIDView *)mraidView
{
    isReady = YES;
    if ([self.delegate respondsToSelector:@selector(mraidInterstitialAdFailed:)]) {
        [self.delegate mraidInterstitialAdFailed:self];
    }
}

- (void)mraidViewWillExpand:(SKMRAIDView *)mraidView
{
    if ([self.delegate respondsToSelector:@selector(mraidInterstitialWillShow:)]) {
        [self.delegate mraidInterstitialWillShow:self];
    }
}

- (void)mraidViewDidClose:(SKMRAIDView *)mv
{
    if ([self.delegate respondsToSelector:@selector(mraidInterstitialDidHide:)]) {
        [self.delegate mraidInterstitialDidHide:self];
    }
    mraidView.delegate = nil;
    mraidView.rootViewController = nil;
    mraidView = nil;
    isReady = NO;
}

- (void)mraidViewNavigate:(SKMRAIDView *)mraidView withURL:(NSURL *)url
{
    if ([self.delegate respondsToSelector:@selector(mraidInterstitialNavigate:withURL:)]) {
        [self.delegate mraidInterstitialNavigate:self withURL:url];
    }
}

#pragma mark - MRAIDServiceDelegate callbacks

- (void)mraidServiceCreateCalendarEventWithEventJSON:(NSString *)eventJSON
{
    if ([self.serviceDelegate respondsToSelector:@selector(mraidServiceCreateCalendarEventWithEventJSON:)]) {
        [self.serviceDelegate mraidServiceCreateCalendarEventWithEventJSON:eventJSON];
    }
}

- (void)mraidServicePlayVideoWithUrlString:(NSString *)urlString
{
    if ([self.serviceDelegate respondsToSelector:@selector(mraidServicePlayVideoWithUrlString:)]) {
        [self.serviceDelegate mraidServicePlayVideoWithUrlString:urlString];
    }
}

- (void)mraidServiceOpenBrowserWithUrlString:(NSString *)urlString
{
    if ([self.serviceDelegate respondsToSelector:@selector(mraidServiceOpenBrowserWithUrlString:)]) {
        [self.serviceDelegate mraidServiceOpenBrowserWithUrlString:urlString];
    }
}

- (void)mraidServiceStorePictureWithUrlString:(NSString *)urlString
{
    if ([self.serviceDelegate respondsToSelector:@selector(mraidServiceStorePictureWithUrlString:)]) {
        [self.serviceDelegate mraidServiceStorePictureWithUrlString:urlString];
    }
}

@end
