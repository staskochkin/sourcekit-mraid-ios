//
//  SKMRAIDView.m
//  MRAID
//
//  Created by Jay Tucker on 9/13/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import "SKMRAIDView.h"
#import "SKMRAIDOrientationProperties.h"
#import "SKMRAIDResizeProperties.h"
#import "SKMRAIDParser.h"
#import "SKMRAIDModalViewController.h"
#import "SKMRAIDServiceDelegate.h"
#import "SKMRAIDUtil.h"
#import "MRAIDSettings.h"

#import "SKLogger.h"

#import "mraidjs.h"
#import "CloseButton.h"

#define kCloseEventRegionSize 50
#define SYSTEM_VERSION_LESS_THAN(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

typedef enum {
    MRAIDStateLoading,
    MRAIDStateDefault,
    MRAIDStateExpanded,
    MRAIDStateResized,
    MRAIDStateHidden
} MRAIDState;

@interface SKMRAIDView () <UIWebViewDelegate, SKMRAIDModalViewControllerDelegate>
{
    MRAIDState state;
    // This corresponds to the MRAID placement type.
    BOOL isInterstitial;
    
    // The only property of the MRAID expandProperties we need to keep track of
    // on the native side is the useCustomClose property.
    // The width, height, and isModal properties are not used in MRAID v2.0.
    BOOL useCustomClose;
    
    SKMRAIDOrientationProperties *orientationProperties;
    SKMRAIDResizeProperties *resizeProperties;
    
    SKMRAIDParser *mraidParser;
    SKMRAIDModalViewController *modalVC;
    
    NSString *mraidjs;
    
    NSURL *baseURL;
    
    NSArray *mraidFeatures;
    NSArray *supportedFeatures;
    
    UIWebView *webView;
    UIWebView *webViewPart2;
    UIWebView *currentWebView;
    
    UIButton *closeEventRegion;
    
    UIView *resizeView;
    UIButton *resizeCloseRegion;
    
    CGSize previousMaxSize;
    CGSize previousScreenSize;
}

// "hidden" method for interstitial support
- (void)showAsInterstitial;

- (void)deviceOrientationDidChange:(NSNotification *)notification;

- (void)addCloseEventRegion;
- (void)showResizeCloseRegion;
- (void)removeResizeCloseRegion;
- (void)setResizeViewPosition;

// These methods provide the means for native code to talk to JavaScript code.
- (void)injectJavaScript:(NSString *)js;
// convenience methods to fire MRAID events
- (void)fireErrorEventWithAction:(NSString *)action message:(NSString *)message;
- (void)fireReadyEvent;
- (void)fireSizeChangeEvent;
- (void)fireStateChangeEvent;
- (void)fireViewableChangeEvent;
// setters
- (void)setDefaultPosition;
-(void)setMaxSize;
-(void)setScreenSize;

// internal helper methods
- (void)initWebView:(UIWebView *)wv;
- (void)parseCommandUrl:(NSString *)commandUrlString;

@end

@implementation SKMRAIDView

@synthesize isViewable=_isViewable;
@synthesize rootViewController = _rootViewController;

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class MRAIDView"
                                 userInfo:nil];
    return nil;
}

- (id)initWithFrame:(CGRect)frame
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-initWithFrame is not a valid initializer for the class MRAIDView"
                                 userInfo:nil];
    return nil;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-initWithCoder is not a valid initializer for the class MRAIDView"
                                 userInfo:nil];
    return nil;
}

- (id)initWithFrame:(CGRect)frame
       withHtmlData:(NSString*)htmlData
        withBaseURL:(NSURL*)bsURL
  supportedFeatures:(NSArray *)features
           delegate:(id<SKMRAIDViewDelegate>)delegate
   serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
 rootViewController:(UIViewController *)rootViewController
{
    return [self initWithFrame:frame
                  withHtmlData:htmlData
                   withBaseURL:bsURL
                asInterstitial:NO
             supportedFeatures:features
                      delegate:delegate
              serviceDelegate:serviceDelegate
            rootViewController:rootViewController];
}

// designated initializer
- (id)initWithFrame:(CGRect)frame
       withHtmlData:(NSString*)htmlData
        withBaseURL:(NSURL*)bsURL
     asInterstitial:(BOOL)isInter
  supportedFeatures:(NSArray *)currentFeatures
           delegate:(id<SKMRAIDViewDelegate>)delegate
   serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
 rootViewController:(UIViewController *)rootViewController
{
    self = [super initWithFrame:frame];
    if (self) {
        isInterstitial = isInter;
        _delegate = delegate;
        _serviceDelegate = serviceDelegate;
        _rootViewController = rootViewController;
        
        state = MRAIDStateLoading;
        _isViewable = NO;
        useCustomClose = NO;
        
        orientationProperties = [[SKMRAIDOrientationProperties alloc] init];
        resizeProperties = [[SKMRAIDResizeProperties alloc] init];
        
        mraidParser = [[SKMRAIDParser alloc] init];
        
        mraidFeatures = @[
                          MRAIDSupportsSMS,
                          MRAIDSupportsTel,
                          MRAIDSupportsCalendar,
                          MRAIDSupportsStorePicture,
                          MRAIDSupportsInlineVideo,
                          ];
        
        if([self isValidFeatureSet:currentFeatures] && serviceDelegate){
            supportedFeatures=currentFeatures;
        }
        
        webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        [self initWebView:webView];
        currentWebView = webView;
        [self addSubview:webView];
        
        previousMaxSize = CGSizeZero;
        previousScreenSize = CGSizeZero;
        
        [self addObserver:self forKeyPath:@"self.frame" options:NSKeyValueObservingOptionOld context:NULL];
 
        // Get mraid.js as binary data
        NSData* mraidJSData = [NSData dataWithBytesNoCopy:__MRAID_mraid_js
                                                   length:__MRAID_mraid_js_len
                                             freeWhenDone:NO];
        mraidjs = [[NSString alloc] initWithData:mraidJSData encoding:NSUTF8StringEncoding];
        mraidJSData = nil;
        
        baseURL = bsURL;
        state = MRAIDStateLoading;
        
        if (mraidjs) {
            [self injectJavaScript:mraidjs];
        }
        
        htmlData = [SKMRAIDUtil processRawHtml:htmlData];
        if (htmlData) {
            [currentWebView loadHTMLString:htmlData baseURL:baseURL];
        } else {
            [SKLogger error:@"MRAID - View" withMessage:@"Ad HTML is invalid, cannot load"];
            if ([self.delegate respondsToSelector:@selector(mraidViewAdFailed:)]) {
                [self.delegate mraidViewAdFailed:self];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"%@ %@", [self.class description], NSStringFromSelector(_cmd)]];
    
    [self removeObserver:self forKeyPath:@"self.frame"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    
    webView = nil;
    webViewPart2 = nil;
    currentWebView = nil;
    
    mraidParser = nil;
    modalVC = nil;
    
    orientationProperties = nil;
    resizeProperties = nil;
    
    mraidFeatures = nil;
    supportedFeatures = nil;
    
    closeEventRegion = nil;
    resizeView = nil;
    resizeCloseRegion = nil;
}

- (BOOL)isValidFeatureSet:(NSArray *)features
{
    NSArray *kFeatures = @[
                           MRAIDSupportsSMS,
                           MRAIDSupportsTel,
                           MRAIDSupportsCalendar,
                           MRAIDSupportsStorePicture,
                           MRAIDSupportsInlineVideo,
                           ];
    
    // Validate the features set by the user
    for (id feature in features) {
        if (![kFeatures containsObject:feature]) {
            [SKLogger warning:@"MRAID - View" withMessage:[NSString stringWithFormat:@"feature %@ is unknown, no supports set", feature]];
            return NO;
        }
    }
    return YES;
}

- (void)setIsViewable:(BOOL)newIsViewable
{
    if(newIsViewable!=_isViewable){
        _isViewable=newIsViewable;
        [self fireViewableChangeEvent];
    }
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat:@"isViewable: %@", _isViewable?@"YES":@"NO"]];
}

- (BOOL)isViewable
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"%@ %@", [self.class description], NSStringFromSelector(_cmd)]];
    return _isViewable;
}

- (void)setRootViewController:(UIViewController *)newRootViewController
{
    if(newRootViewController!=_rootViewController) {
        _rootViewController=newRootViewController;
    }
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat:@"setRootViewController: %@", _rootViewController]];
}

- (void)deviceOrientationDidChange:(NSNotification *)notification
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"%@ %@", [self.class description], NSStringFromSelector(_cmd)]];
    @synchronized (self) {
        [self setScreenSize];
        [self setMaxSize];
        [self setDefaultPosition];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (!([keyPath isEqualToString:@"self.frame"])) {
        return;
    }
    
    [SKLogger debug:@"MRAID - View" withMessage:@"self.frame has changed"];
    
    CGRect oldFrame = CGRectNull;
    CGRect newFrame = CGRectNull;
    if (change[@"old"] != [NSNull null]) {
        oldFrame = [change[@"old"] CGRectValue];
    }
    if ([object valueForKeyPath:keyPath] != [NSNull null]) {
        newFrame = [[object valueForKeyPath:keyPath] CGRectValue];
    }
    
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat:@"old %@", NSStringFromCGRect(oldFrame)]];
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat:@"new %@", NSStringFromCGRect(newFrame)]];
    
    if (state == MRAIDStateResized) {
        [self setResizeViewPosition];
    }
    [self setDefaultPosition];
    [self setMaxSize];
    [self fireSizeChangeEvent];
}

-(void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    currentWebView.backgroundColor = backgroundColor;
}

#pragma mark - interstitial support

- (void)showAsInterstitial
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"%@", NSStringFromSelector(_cmd)]];
    [self expand:nil];
}

#pragma mark - JavaScript --> native support

// These methods are (indirectly) called by JavaScript code.
// They provide the means for JavaScript code to talk to native code

- (void)close
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@", NSStringFromSelector(_cmd)]];
    
    if (state == MRAIDStateLoading ||
        (state == MRAIDStateDefault && !isInterstitial) ||
        state == MRAIDStateHidden) {
        // do nothing
        return;
    }
    
    if (state == MRAIDStateResized) {
        [self closeFromResize];
        return;
    }
    
    if (modalVC) {
        [closeEventRegion removeFromSuperview];
        closeEventRegion = nil;
        [currentWebView removeFromSuperview];
        if ([modalVC respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
            // used if running >= iOS 6
            [modalVC dismissViewControllerAnimated:NO completion:nil];
        } else {
            // Turn off the warning about using a deprecated method.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [modalVC dismissModalViewControllerAnimated:NO];
#pragma clang diagnostic pop
        }
    }
    
    modalVC = nil;
    
    if (webViewPart2) {
        // Clean up webViewPart2 if returning from 2-part expansion.
        webViewPart2.delegate = nil;
        currentWebView = webView;
        webViewPart2 = nil;
    } else {
        // Reset frame of webView if returning from 1-part expansion.
        webView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    }
    
    [self addSubview:webView];
    
    if (!isInterstitial) {
        [self fireSizeChangeEvent];
    } else {
        self.isViewable = NO;
        [self fireViewableChangeEvent];
    }
    
    if (state == MRAIDStateDefault && isInterstitial) {
        state = MRAIDStateHidden;
    } else if (state == MRAIDStateExpanded || state == MRAIDStateResized) {
        state = MRAIDStateDefault;
    }
    [self fireStateChangeEvent];
    
    if ([self.delegate respondsToSelector:@selector(mraidViewDidClose:)]) {
        [self.delegate mraidViewDidClose:self];
    }
}

// This is a helper method which is not part of the official MRAID API.
- (void)closeFromResize
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback helper %@", NSStringFromSelector(_cmd)]];
    [self removeResizeCloseRegion];
    state = MRAIDStateDefault;
    [self fireStateChangeEvent];
    [webView removeFromSuperview];
    webView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    [self addSubview:webView];
    [resizeView removeFromSuperview];
    resizeView = nil;
    [self fireSizeChangeEvent];
    if ([self.delegate respondsToSelector:@selector(mraidViewDidClose:)]) {
        [self.delegate mraidViewDidClose:self];
    }
}

- (void)createCalendarEvent:(NSString *)eventJSON
{
    eventJSON=[eventJSON stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@ %@", NSStringFromSelector(_cmd), eventJSON]];
    
    if ([supportedFeatures containsObject:MRAIDSupportsCalendar]) {
        if ([self.serviceDelegate respondsToSelector:@selector(mraidServiceCreateCalendarEventWithEventJSON:)]) {
            [self.serviceDelegate mraidServiceCreateCalendarEventWithEventJSON:eventJSON];
        }
    } else {
        [SKLogger warning:@"MRAID - View" withMessage:[NSString stringWithFormat:@"No calendar support has been included."]];
   }
}

// Note: This method is also used to present an interstitial ad.
- (void)expand:(NSString *)urlString
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@ %@", NSStringFromSelector(_cmd), (urlString ? urlString : @"1-part")]];
    
    // The only time it is valid to call expand is when the ad is currently in either default or resized state.
    if (state != MRAIDStateDefault && state != MRAIDStateResized) {
        // do nothing
        return;
    }
    
    modalVC = [[SKMRAIDModalViewController alloc] initWithOrientationProperties:orientationProperties];
    CGRect frame = [[UIScreen mainScreen] bounds];
    modalVC.view.frame = frame;
    modalVC.delegate = self;
    
    if (!urlString) {
        // 1-part expansion
        webView.frame = frame;
        [webView removeFromSuperview];
    } else {
        // 2-part expansion
        webViewPart2 = [[UIWebView alloc] initWithFrame:frame];
        [self initWebView:webViewPart2];
        currentWebView = webViewPart2;
        
        if (mraidjs) {
            [self injectJavaScript:mraidjs];
        }
        
        // Check to see whether we've been given an absolute or relative URL.
        // If it's relative, prepend the base URL.
        urlString = [urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (![[NSURL URLWithString:urlString] scheme]) {
            // relative URL
            urlString = [[[baseURL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByAppendingString:urlString];
        }
        
        // Need to escape characters which are URL specific
        urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSError *error;
        NSString *content = [NSString stringWithContentsOfURL:[NSURL URLWithString:urlString] encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            [webViewPart2 loadHTMLString:content baseURL:baseURL];
        } else {
            // Error! Clean up and return.
            [SKLogger error:@"MRAID - View" withMessage:[NSString stringWithFormat:@"Could not load part 2 expanded content for URL: %@" ,urlString]];
            currentWebView = webView;
            webViewPart2.delegate = nil;
            webViewPart2 = nil;
            modalVC = nil;
            return;
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(mraidViewWillExpand:)]) {
        [self.delegate mraidViewWillExpand:self];
    }
    
    [modalVC.view addSubview:currentWebView];
    
    // always include the close event region
    [self addCloseEventRegion];
    
    if ([self.rootViewController respondsToSelector:@selector(presentViewController:animated:completion:)]) {
        // used if running >= iOS 6
        if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {  // respect clear backgroundColor
            self.rootViewController.navigationController.modalPresentationStyle = UIModalPresentationCurrentContext;
        } else {
            modalVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        }
        [self.rootViewController presentViewController:modalVC animated:NO completion:nil];
    } else {
        // Turn off the warning about using a deprecated method.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.rootViewController presentModalViewController:modalVC animated:NO];
#pragma clang diagnostic pop
    }
    
    if (!isInterstitial) {
        state = MRAIDStateExpanded;
        [self fireStateChangeEvent];
    }
    [self fireSizeChangeEvent];
    self.isViewable = YES;
}

- (void)open:(NSString *)urlString
{
    urlString = [urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@ %@", NSStringFromSelector(_cmd), urlString]];
    
    // Notify the callers
    if ([self.serviceDelegate respondsToSelector:@selector(mraidServiceOpenBrowserWithUrlString:)]) {
        [self.serviceDelegate mraidServiceOpenBrowserWithUrlString:urlString];
    }
}

- (void)playVideo:(NSString *)urlString
{
    urlString = [urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@ %@", NSStringFromSelector(_cmd), urlString]];
    if ([self.serviceDelegate respondsToSelector:@selector(mraidServicePlayVideoWithUrlString:)]) {
        [self.serviceDelegate mraidServicePlayVideoWithUrlString:urlString];
    }
}

- (void)resize
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@", NSStringFromSelector(_cmd)]];
    // If our delegate doesn't respond to the mraidViewShouldResizeToPosition:allowOffscreen: message,
    // then we can't do anything. We need help from the app here.
    if (![self.delegate respondsToSelector:@selector(mraidViewShouldResize:toPosition:allowOffscreen:)]) {
        return;
    }
    
    CGRect resizeFrame = CGRectMake(resizeProperties.offsetX, resizeProperties.offsetY, resizeProperties.width, resizeProperties.height);
    // The offset of the resize frame is relative to the origin of the default banner.
    CGPoint bannerOriginInRootView = [self.rootViewController.view convertPoint:CGPointZero fromView:self];
    resizeFrame.origin.x += bannerOriginInRootView.x;
    resizeFrame.origin.y += bannerOriginInRootView.y;
    
    if (![self.delegate mraidViewShouldResize:self toPosition:resizeFrame allowOffscreen:resizeProperties.allowOffscreen]) {
        return;
    }
    
    // resize here
    state = MRAIDStateResized;
    [self fireStateChangeEvent];
    
    if (!resizeView) {
        resizeView = [[UIView alloc] initWithFrame:resizeFrame];
        [webView removeFromSuperview];
        [resizeView addSubview:webView];
        [self.rootViewController.view addSubview:resizeView];
    }
    
    resizeView.frame = resizeFrame;
    webView.frame = resizeView.bounds;
    [self showResizeCloseRegion];
    [self fireSizeChangeEvent];
}

- (void)setOrientationProperties:(NSDictionary *)properties;
{
    BOOL allowOrientationChange = [[properties valueForKey:@"allowOrientationChange"] boolValue];
    NSString *forceOrientation = [properties valueForKey:@"forceOrientation"];
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@ %@ %@", NSStringFromSelector(_cmd), (allowOrientationChange ? @"YES" : @"NO"), forceOrientation]];
    orientationProperties.allowOrientationChange = allowOrientationChange;
    orientationProperties.forceOrientation = [SKMRAIDOrientationProperties MRAIDForceOrientationFromString:forceOrientation];
    [modalVC forceToOrientation:orientationProperties];
}

- (void)setResizeProperties:(NSDictionary *)properties;
{
    int width = [[properties valueForKey:@"width"] intValue];
    int height = [[properties valueForKey:@"height"] intValue];
    int offsetX = [[properties valueForKey:@"offsetX"] intValue];
    int offsetY = [[properties valueForKey:@"offsetY"] intValue];
    NSString *customClosePosition = [properties valueForKey:@"customClosePosition"];
    BOOL allowOffscreen = [[properties valueForKey:@"allowOffscreen"] boolValue];
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@ %d %d %d %d %@ %@", NSStringFromSelector(_cmd), width, height, offsetX, offsetY, customClosePosition, (allowOffscreen ? @"YES" : @"NO")]];
    resizeProperties.width = width;
    resizeProperties.height = height;
    resizeProperties.offsetX = offsetX;
    resizeProperties.offsetY = offsetY;
    resizeProperties.customClosePosition = [SKMRAIDResizeProperties MRAIDCustomClosePositionFromString:customClosePosition];
    resizeProperties.allowOffscreen = allowOffscreen;
}

-(void)storePicture:(NSString *)urlString
{
    urlString=[urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@ %@", NSStringFromSelector(_cmd), urlString]];
    
    if ([supportedFeatures containsObject:MRAIDSupportsStorePicture]) {
        if ([self.serviceDelegate respondsToSelector:@selector(mraidServiceStorePictureWithUrlString:)]) {
            [self.serviceDelegate mraidServiceStorePictureWithUrlString:urlString];
        }
    } else {
        [SKLogger warning:@"MRAID - View" withMessage:[NSString stringWithFormat:@"No MRAIDSupportsStorePicture feature has been included"]];
    }
}

- (void)useCustomClose:(NSString *)isCustomCloseString
{
    BOOL isCustomClose = [isCustomCloseString boolValue];
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@ %@", NSStringFromSelector(_cmd), (isCustomClose ? @"YES" : @"NO")]];
    useCustomClose = isCustomClose;
}

#pragma mark - JavaScript --> native support helpers

// These methods are helper methods for the ones above.

- (void)addCloseEventRegion
{
    closeEventRegion = [UIButton buttonWithType:UIButtonTypeCustom];
    closeEventRegion.backgroundColor = [UIColor clearColor];
    [closeEventRegion addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    
    if (!useCustomClose) {
        // get button image from header file
        NSData* buttonData = [NSData dataWithBytesNoCopy:__MRAID_CloseButton_png
                                                  length:__MRAID_CloseButton_png_len
                                            freeWhenDone:NO];
        UIImage *closeButtonImage = [UIImage imageWithData:buttonData];
        [closeEventRegion setBackgroundImage:closeButtonImage forState:UIControlStateNormal];
    }
    
    closeEventRegion.frame = CGRectMake(0, 0, kCloseEventRegionSize, kCloseEventRegionSize);
    CGRect frame = closeEventRegion.frame;
    
    // align on top right
    int x = CGRectGetWidth(modalVC.view.frame) - CGRectGetWidth(frame);
    frame.origin = CGPointMake(x, 0);
    closeEventRegion.frame = frame;
    // autoresizing so it stays at top right (flexible left and flexible bottom margin)
    closeEventRegion.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [modalVC.view addSubview:closeEventRegion];
}

- (void)showResizeCloseRegion
{
    if (!resizeCloseRegion) {
        resizeCloseRegion = [UIButton buttonWithType:UIButtonTypeCustom];
        resizeCloseRegion.frame = CGRectMake(0, 0, kCloseEventRegionSize, kCloseEventRegionSize);
        resizeCloseRegion.backgroundColor = [UIColor clearColor];
        [resizeCloseRegion addTarget:self action:@selector(closeFromResize) forControlEvents:UIControlEventTouchUpInside];
        [resizeView addSubview:resizeCloseRegion];
    }
    
    // align appropriately
    int x;
    int y;
    UIViewAutoresizing autoresizingMask = UIViewAutoresizingNone;
    
    switch (resizeProperties.customClosePosition) {
        case MRAIDCustomClosePositionTopLeft:
        case MRAIDCustomClosePositionBottomLeft:
            x = 0;
            break;
        case MRAIDCustomClosePositionTopCenter:
        case MRAIDCustomClosePositionCenter:
        case MRAIDCustomClosePositionBottomCenter:
            x = (CGRectGetWidth(resizeView.frame) - CGRectGetWidth(resizeCloseRegion.frame)) / 2;
            autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
            break;
        case MRAIDCustomClosePositionTopRight:
        case MRAIDCustomClosePositionBottomRight:
            x = CGRectGetWidth(resizeView.frame) - CGRectGetWidth(resizeCloseRegion.frame);
            autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            break;
    }
    
    switch (resizeProperties.customClosePosition) {
        case MRAIDCustomClosePositionTopLeft:
        case MRAIDCustomClosePositionTopCenter:
        case MRAIDCustomClosePositionTopRight:
            y = 0;
            break;
        case MRAIDCustomClosePositionCenter:
            y = (CGRectGetHeight(resizeView.frame) - CGRectGetHeight(resizeCloseRegion.frame)) / 2;
            autoresizingMask |= UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            break;
        case MRAIDCustomClosePositionBottomLeft:
        case MRAIDCustomClosePositionBottomCenter:
        case MRAIDCustomClosePositionBottomRight:
            y = CGRectGetHeight(resizeView.frame) - CGRectGetHeight(resizeCloseRegion.frame);
            autoresizingMask |= UIViewAutoresizingFlexibleTopMargin;
            break;
    }
    
    CGRect resizeCloseRegionFrame = resizeCloseRegion.frame;
    resizeCloseRegionFrame.origin = CGPointMake(x, y);
    resizeCloseRegion.frame = resizeCloseRegionFrame;
    resizeCloseRegion.autoresizingMask = autoresizingMask;
}

- (void)removeResizeCloseRegion
{
    if (resizeCloseRegion) {
        [resizeCloseRegion removeFromSuperview];
        resizeCloseRegion = nil;
    }
}

- (void)setResizeViewPosition
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"%@", NSStringFromSelector(_cmd)]];
    CGRect oldResizeFrame = resizeView.frame;
    CGRect newResizeFrame = CGRectMake(resizeProperties.offsetX, resizeProperties.offsetY, resizeProperties.width, resizeProperties.height);
    // The offset of the resize frame is relative to the origin of the default banner.
    CGPoint bannerOriginInRootView = [self.rootViewController.view convertPoint:CGPointZero fromView:self];
    newResizeFrame.origin.x += bannerOriginInRootView.x;
    newResizeFrame.origin.y += bannerOriginInRootView.y;
    if (!CGRectEqualToRect(oldResizeFrame, newResizeFrame)) {
        resizeView.frame = newResizeFrame;
    }
}

#pragma mark - native -->  JavaScript support

- (void)injectJavaScript:(NSString *)js
{
    [currentWebView stringByEvaluatingJavaScriptFromString:js];
}

// convenience methods
- (void)fireErrorEventWithAction:(NSString *)action message:(NSString *)message
{
    [self injectJavaScript:[NSString stringWithFormat:@"mraid.fireErrorEvent('%@','%@');", message, action]];
}

- (void)fireReadyEvent
{
    [self injectJavaScript:@"mraid.fireReadyEvent()"];
}

- (void)fireSizeChangeEvent
{
    @synchronized(self){
        int x;
        int y;
        int width;
        int height;
        if (state == MRAIDStateExpanded || isInterstitial) {
            x = (int)currentWebView.frame.origin.x;
            y = (int)currentWebView.frame.origin.y;
            width = (int)currentWebView.frame.size.width;
            height = (int)currentWebView.frame.size.height;
        } else if (state == MRAIDStateResized) {
            x = (int)resizeView.frame.origin.x;
            y = (int)resizeView.frame.origin.y;
            width = (int)resizeView.frame.size.width;
            height = (int)resizeView.frame.size.height;
        } else {
            // Per the MRAID spec, the current or default position is relative to the rectangle defined by the getMaxSize method,
            // that is, the largest size that the ad can resize to.
            CGPoint originInRootView = [self.rootViewController.view convertPoint:CGPointZero fromView:self];
            x = originInRootView.x;
            y = originInRootView.y;
            width = (int)self.frame.size.width;
            height = (int)self.frame.size.height;
        }
        
        UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
        BOOL isLandscape = UIInterfaceOrientationIsLandscape(interfaceOrientation);
        // [SKLogger debug:[NSString stringWithFormat:@"orientation is %@", (isLandscape ?  @"landscape" : @"portrait")]];
        BOOL adjustOrientationForIOS8 = isInterstitial &&  isLandscape && !SYSTEM_VERSION_LESS_THAN(@"8.0");
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.setCurrentPosition(%d,%d,%d,%d);", x, y, adjustOrientationForIOS8?height:width, adjustOrientationForIOS8?width:height]];
    }
}

- (void)fireStateChangeEvent
{
    @synchronized(self) {
        NSArray *stateNames = @[
                                @"loading",
                                @"default",
                                @"expanded",
                                @"resized",
                                @"hidden",
                                ];
        
        NSString *stateName = stateNames[state];
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.fireStateChangeEvent('%@');", stateName]];
    }
}

- (void)fireViewableChangeEvent
{
    [self injectJavaScript:[NSString stringWithFormat:@"mraid.fireViewableChangeEvent(%@);", (self.isViewable ? @"true" : @"false")]];
}

- (void)setDefaultPosition
{
    if (isInterstitial) {
        // For interstitials, we define defaultPosition to be the same as screen size, so set the value there.
        return;
    }
    
    // getDefault position from the parent frame if we are not directly added to the rootview
    if(self.superview != self.rootViewController.view) {
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.setDefaultPosition(%f,%f,%f,%f);", self.superview.frame.origin.x, self.superview.frame.origin.y, self.superview.frame.size.width, self.superview.frame.size.height]];
    } else {
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.setDefaultPosition(%f,%f,%f,%f);", self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height]];
    }
}

-(void)setMaxSize
{
    if (isInterstitial) {
        // For interstitials, we define maxSize to be the same as screen size, so set the value there.
        return;
    }
    CGSize maxSize = self.rootViewController.view.bounds.size;
    if (!CGSizeEqualToSize(maxSize, previousMaxSize)) {
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.setMaxSize(%d,%d);",
                                (int)maxSize.width,
                                (int)maxSize.height]];
        previousMaxSize = CGSizeMake(maxSize.width, maxSize.height);
    }
}

-(void)setScreenSize
{
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    // screenSize is ALWAYS for portrait orientation, so we need to figure out the
    // actual interface orientation to get the correct current screenRect.
    UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(interfaceOrientation);
    // [SKLogger debug:[NSString stringWithFormat:@"orientation is %@", (isLandscape ?  @"landscape" : @"portrait")]];
   
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        screenSize = CGSizeMake(screenSize.width, screenSize.height);
    } else {
        if (isLandscape) {
            screenSize = CGSizeMake(screenSize.height, screenSize.width);
        }
    }
    if (!CGSizeEqualToSize(screenSize, previousScreenSize)) {
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.setScreenSize(%d,%d);",
                                (int)screenSize.width,
                                (int)screenSize.height]];
        previousScreenSize = CGSizeMake(screenSize.width, screenSize.height);
        if (isInterstitial) {
            [self injectJavaScript:[NSString stringWithFormat:@"mraid.setMaxSize(%d,%d);",
                                    (int)screenSize.width,
                                    (int)screenSize.height]];
            [self injectJavaScript:[NSString stringWithFormat:@"mraid.setDefaultPosition(0,0,%d,%d);",
                                    (int)screenSize.width,
                                    (int)screenSize.height]];
        }
    }
}

-(void)setSupports:(NSArray *)currentFeatures
{
    for (id aFeature in mraidFeatures) {
            [self injectJavaScript:[NSString stringWithFormat:@"mraid.setSupports('%@',%@);", aFeature,[currentFeatures containsObject:aFeature]?@"true":@"false"]];
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)wv
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@", NSStringFromSelector(_cmd)]];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv
{
    @synchronized(self) {
        [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@", NSStringFromSelector(_cmd)]];
        
        // If wv is webViewPart2, that means the part 2 expanded web view has just loaded.
        // In this case, state should already be MRAIDStateExpanded and should not be changed.
        // if (wv != webViewPart2) {
        
        if (ENABLE_JS_LOG) {
            [wv stringByEvaluatingJavaScriptFromString:@"var enableLog = true"];
        }
        
        if (state == MRAIDStateLoading) {
            state = MRAIDStateDefault;
            [self injectJavaScript:[NSString stringWithFormat:@"mraid.setPlacementType('%@');", (isInterstitial ? @"interstitial" : @"inline")]];
            [self setSupports:supportedFeatures];
            [self setDefaultPosition];
            [self setMaxSize];
            [self setScreenSize];
            [self fireStateChangeEvent];
            [self fireSizeChangeEvent];
            [self fireReadyEvent];
            
            if ([self.delegate respondsToSelector:@selector(mraidViewAdReady:)]) {
                [self.delegate mraidViewAdReady:self];
            }
            
            // Start monitoring device orientation so we can reset max Size and screenSize if needed.
            [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(deviceOrientationDidChange:)
                                                         name:UIDeviceOrientationDidChangeNotification
                                                       object:nil];
        }
    }
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"JS callback %@", NSStringFromSelector(_cmd)]];
}

- (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = [request URL];
    NSString *scheme = [url scheme];
    NSString *absUrlString = [url absoluteString];
    
    if ([scheme isEqualToString:@"mraid"]) {
        [self parseCommandUrl:absUrlString];

    } else if ([scheme isEqualToString:@"console-log"]) {
        [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat:@"JS console: %@",
                          [[absUrlString substringFromIndex:14] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding ]]];
    } else {
        [SKLogger info:@"MRAID - View" withMessage:[NSString stringWithFormat:@"Found URL %@ with type %@", absUrlString, @(navigationType)]];
        
        // Links, Form submissions
        if (navigationType == UIWebViewNavigationTypeLinkClicked) {
            // For banner views
            if ([self.delegate respondsToSelector:@selector(mraidViewNavigate:withURL:)]) {
                [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat:@"JS webview load: %@",
                                                                    [absUrlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
                [self.delegate mraidViewNavigate:self withURL:url];
            }
        } else {
            // Need to let browser to handle rendering and other things
            return YES;
        }
    }
    return NO;
}

#pragma mark - MRAIDModalViewControllerDelegate

- (void)mraidModalViewControllerDidRotate:(SKMRAIDModalViewController *)modalViewController
{
    [SKLogger debug:@"MRAID - View" withMessage:[NSString stringWithFormat: @"%@", NSStringFromSelector(_cmd)]];
    [self setScreenSize];
    [self fireSizeChangeEvent];
}

#pragma mark - internal helper methods

- (void)initWebView:(UIWebView *)wv
{
    wv.delegate = self;
    wv.opaque = NO;
    wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    wv.autoresizesSubviews = YES;
    
    if ([supportedFeatures containsObject:MRAIDSupportsInlineVideo]) {
        wv.allowsInlineMediaPlayback = YES;
        wv.mediaPlaybackRequiresUserAction = NO;
    } else {
        wv.allowsInlineMediaPlayback = NO;
        wv.mediaPlaybackRequiresUserAction = YES;
        [SKLogger warning:@"MRAID - View" withMessage:[NSString stringWithFormat:@"No inline video support has been included, videos will play full screen without autoplay."]];
    }
    
    // disable scrolling
    UIScrollView *scrollView;
    if ([wv respondsToSelector:@selector(scrollView)]) {
        // UIWebView has a scrollView property in iOS 5+.
        scrollView = [wv scrollView];
    } else {
        // We have to look for the UIWebView's scrollView in iOS 4.
        for (id subview in [self subviews]) {
            if ([subview isKindOfClass:[UIScrollView class]]) {
                scrollView = subview;
                break;
            }
        }
    }
    scrollView.scrollEnabled = NO;
    
    // disable selection
    NSString *js = @"window.getSelection().removeAllRanges();";
    [wv stringByEvaluatingJavaScriptFromString:js];
}

- (void)parseCommandUrl:(NSString *)commandUrlString
{
    NSDictionary *commandDict = [mraidParser parseCommandUrl:commandUrlString];
    if (!commandDict) {
        [SKLogger warning:@"MRAID - View" withMessage:[NSString stringWithFormat:@"invalid command URL: %@", commandUrlString]];
        return;
    }
    
    NSString *command = [commandDict valueForKey:@"command"];
    NSObject *paramObj = [commandDict valueForKey:@"paramObj"];
    
    SEL selector = NSSelectorFromString(command);
    
    // Turn off the warning "PerformSelector may cause a leak because its selector is unknown".
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    
    [self performSelector:selector withObject:paramObj];
    
#pragma clang diagnostic pop
}

@end
