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

@property (nonatomic, assign, getter=isAdReady) BOOL isReady;
@property (nonatomic, strong) SKMRAIDView *mraidView;
@property (nonatomic, strong) NSArray* supportedFeatures;

@end

@implementation SKMRAIDInterstitial

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class MRAIDInterstitial"
                                 userInfo:nil];
    return nil;
}

- (void) dealloc
{
    self.mraidView = nil;
    self.supportedFeatures = nil;
}

- (void)preloadAdFromURL:(NSURL *)url {
    [self.mraidView preloadAdFromURL:url];
}

#pragma mark - Designated initializers

- (instancetype)initWithSupportedFeatures:(NSArray *)features
                                 delegate:(id<SKMRAIDInterstitialDelegate>)delegate
                          serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
                       rootViewController:(UIViewController *)rootViewController {
    return [[SKMRAIDInterstitial alloc] initWithSupportedFeatures:features
                                                         delegate:delegate
                                                  serviceDelegate:serviceDelegate
                                                    customScripts:nil
                                               rootViewController:rootViewController];
}

- (instancetype)initWithSupportedFeatures:(NSArray *)features
                                 delegate:(id<SKMRAIDInterstitialDelegate>)delegate
                          serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
                            customScripts:(NSArray *)customScripts
                       rootViewController:(UIViewController *)rootViewController {
    self = [super init];
    if (self) {
        self.supportedFeatures = features;
        _delegate = delegate;
        _serviceDelegate = serviceDelegate;
        _rootViewController = rootViewController;
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        self.mraidView = [[SKMRAIDView alloc] initWithFrame:screenRect
                                             asInterstitial:YES
                                          supportedFeatures:features
                                                   delegate:self
                                            serviceDelegate:serviceDelegate
                                              customScripts:customScripts
                                         rootViewController:rootViewController];
        _isReady = NO;
    }
    return self;
}

- (void)setDoubleClickDelegate:(id<SKMRAIDDoubleClickDelegate>)doubleClickDelegate {
    self.mraidView.doubleClickDelegate = doubleClickDelegate;
}

- (id<SKMRAIDDoubleClickDelegate>)doubleClickDelegate {
    return self.mraidView.doubleClickDelegate;
}

- (void)loadAdHTML:(NSString *)html {
    [self.mraidView loadAdHTML:html];
}

- (void)loadAdHTML:(NSString *)html estimatedAdSize:(CGSize)estimatedAdSize {
    [self.mraidView loadAdHTML:html estimatedAdSize:estimatedAdSize];
}

- (void)cancel {
    [self.mraidView cancel];
}

- (void)close {
    [self.mraidView close];
}

- (NSURL *)baseURL {
    return self.mraidView.baseURL;
}

- (void)setBaseURL:(NSURL *)baseURL {
    self.mraidView.baseURL = baseURL;
}

- (void)show
{
    if (!_isReady) return;
    [self.mraidView showAsInterstitial];
}

- (void)injectJavaScript:(NSString *)js {
    [self.mraidView injectJavaScript:js];
}

- (void)setRootViewController:(UIViewController *)newRootViewController
{
    self.mraidView.rootViewController = newRootViewController;
}

-(void)setBackgroundColor:(UIColor *)backgroundColor
{
    self.mraidView.backgroundColor = backgroundColor;
}

#pragma mark - MRAIDViewDelegate

- (void)mraidViewAdReady:(SKMRAIDView *)mraidView
{
    self.isReady = YES;
    if ([self.delegate respondsToSelector:@selector(mraidInterstitialAdReady:)]) {
        [self.delegate mraidInterstitialAdReady:self];
    }
}

- (void)mraidViewAdFailed:(SKMRAIDView *)mraidView
{
    self.isReady = YES;
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
    self.mraidView.delegate = nil;
    self.mraidView.rootViewController = nil;
    self.mraidView = nil;
    self.isReady = NO;
}

- (void)mraidViewNavigate:(SKMRAIDView *)mraidView withURL:(NSURL *)url
{
    if ([self.delegate respondsToSelector:@selector(mraidInterstitialNavigate:withURL:)]) {
        [self.delegate mraidInterstitialNavigate:self withURL:url];
    }
}

- (void)mraidView:(SKMRAIDView *)mraidView preloadedAd:(NSString *)preloadedAd {
    if ([self.delegate respondsToSelector:@selector(mraidInterstitial:didFailToPreloadAd:)]) {
        [self.delegate mraidInterstitial:self preloadedAd:preloadedAd];
    }
}

- (void)mraidView:(SKMRAIDView *)mraidView didFailToPreloadAd:(NSError *)preloadError {
    if ([self.delegate respondsToSelector:@selector(mraidInterstitial:didFailToPreloadAd:)]) {
        [self.delegate mraidInterstitial:self didFailToPreloadAd:preloadError];
    }
}

- (void)mraidView:(SKMRAIDView *)mraidView requierToUseCustomCloseInView:(UIView *)view {
    if ([self.delegate respondsToSelector:@selector(mraidInterstitial:requierToUseCustomCloseInView:)]) {
        [self.delegate mraidInterstitial:self requierToUseCustomCloseInView:view];
    }
}

- (void)mraidView:(SKMRAIDView *)mraidView intersectJsLogMessage:(NSString *)logMessage {
    if ([self.delegate respondsToSelector:@selector(mraidInterstitial:intersectJsLogMessage:)]) {
        [self.delegate mraidInterstitial:self intersectJsLogMessage:logMessage];
    }
}

@end
