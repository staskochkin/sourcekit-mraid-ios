//
//  SKMRAIDView.m
//  MRAID
//
//  Created by Jay Tucker on 9/13/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "SKMRAIDView.h"
#import "SKMRAIDOrientationProperties.h"
#import "SKMRAIDResizeProperties.h"
#import "SKMRAIDParser.h"
#import "SKMRAIDModalViewController.h"
#import "SKMRAIDServiceDelegate.h"
#import "SKMRAIDUtil.h"
#import "MRAIDSettings.h"
#import "UIButton+SKExtension.h"

#import "mraidjs.h"
#import "CloseButton.h"

#define kCloseEventRegionSize 20
#define kCloseEventRegionInset -30
#define kStatusBarOffset 25
#define kMinHTMLResponseLength 70
#define SYSTEM_VERSION_LESS_THAN(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

#define kScriptObserverName @"observe"
#define kLogHandlerName @"logHandler"

NSString *const kSKMRAIDErrorDomain = @"com.skmraid.error";

typedef enum {
    MRAIDStateLoading,
    MRAIDStateDefault,
    MRAIDStateExpanded,
    MRAIDStateResized,
    MRAIDStateHidden
} MRAIDState;

@interface SKMRAIDView () <WKNavigationDelegate, WKScriptMessageHandler, SKMRAIDModalViewControllerDelegate, UIGestureRecognizerDelegate, WKUIDelegate>

@property (nonatomic, assign) MRAIDState state;
    // This corresponds to the MRAID placement type.
@property (nonatomic, assign) BOOL isInterstitial;
    
    // The only property of the MRAID expandProperties we need to keep track of
    // on the native side is the useCustomClose property.
    // The width, height, and isModal properties are not used in MRAID v2.0.
@property (nonatomic, assign) BOOL useCustomClose;
    
@property (nonatomic, strong) SKMRAIDOrientationProperties *orientationProperties;
@property (nonatomic, strong) SKMRAIDResizeProperties *resizeProperties;
    
@property (nonatomic, strong) SKMRAIDParser *mraidParser;
@property (nonatomic, strong) SKMRAIDModalViewController *modalVC;
    
@property (nonatomic, strong) NSString *mraidjs;
    
@property (nonatomic, strong) NSArray *mraidFeatures;
@property (nonatomic, strong) NSArray *supportedFeatures;
    
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKWebView *webViewPart2;
@property (nonatomic, strong) WKWebView *currentWebView;
    
@property (nonatomic, strong) UIButton *closeEventRegion;
    
@property (nonatomic, strong) UIView *resizeView;
@property (nonatomic, strong) UIButton *resizeCloseRegion;

@property (nonatomic, assign) CGSize estimatedAdSize;
@property (nonatomic, assign) CGSize previousMaxSize;
@property (nonatomic, assign) CGSize previousScreenSize;

@property (nonatomic, strong) NSArray * customScripts;

@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, assign) BOOL bonafideTapObserved;

@end


@implementation SKMRAIDView


#pragma mark - Designated Initilizers

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

#pragma mark - Public

- (instancetype)initWithFrame:(CGRect)frame
            supportedFeatures:(NSArray *)features
                     delegate:(id<SKMRAIDViewDelegate>)delegate
              serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
           rootViewController:(UIViewController *)rootViewController {
    return [self initWithFrame:frame
             supportedFeatures:features
                      delegate:delegate
               serviceDelegate:serviceDelegate
                 customScripts:nil
            rootViewController:rootViewController];
}


- (instancetype)initWithFrame:(CGRect)frame
            supportedFeatures:(NSArray *)features
                     delegate:(id<SKMRAIDViewDelegate>)delegate
              serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
                customScripts:(NSArray *)customScripts
           rootViewController:(UIViewController *)rootViewController {
    return [self initWithFrame:frame
                asInterstitial:NO
             supportedFeatures:features
                      delegate:delegate
               serviceDelegate:serviceDelegate
                 customScripts:customScripts
            rootViewController:rootViewController];
}

- (void)preloadAdFromURL:(NSURL *)url {
    __weak typeof(self) weakSelf = self;
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 500;
        if (error || !data || code >= 400) {
            NSError * mraidError = [NSError errorWithDomain:kSKMRAIDErrorDomain code:MRAIDPreloadNetworkError userInfo:error.userInfo];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([weakSelf.delegate respondsToSelector:@selector(mraidView:didFailToPreloadAd:)]) {
                    [weakSelf.delegate mraidView:weakSelf didFailToPreloadAd:mraidError];
                }
            });
            return;
        }
        
        NSString * downloadedData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([downloadedData length] < kMinHTMLResponseLength) {
            NSError * mraidError = [NSError errorWithDomain:kSKMRAIDErrorDomain code:MRAIDPreloadNoFillError userInfo:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([weakSelf.delegate respondsToSelector:@selector(mraidView:didFailToPreloadAd:)]) {
                    [weakSelf.delegate mraidView:weakSelf didFailToPreloadAd:mraidError];
                }
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([weakSelf.delegate respondsToSelector:@selector(mraidView:preloadedAd:)]) {
                [weakSelf.delegate mraidView:weakSelf preloadedAd:downloadedData];
            }
        });
        
    }] resume];
}

- (void)loadAdHTML:(NSString *)html estimatedAdSize:(CGSize)estimatedAdSize {
    self.estimatedAdSize = estimatedAdSize;
    [self loadAdHTML:html];
}

- (void)loadAdHTML:(NSString *)html {
    if (!html) {
        if ([self.delegate respondsToSelector:@selector(mraidView:failToLoadAdThrowError:)]) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"HTML cannot be nil", nil)};
            NSError * error = [NSError errorWithDomain:kSKMRAIDErrorDomain code:MRAIDValidationError userInfo:userInfo];
            [self.delegate mraidView:self failToLoadAdThrowError:error];
        }
        return;
    }
    
    
    self.webView = [self defaultWebViewWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
    self.currentWebView = self.webView;
    
    [self addSubview:self.currentWebView];
    // Get mraid.js as binary data
    NSData* mraidJSData = [NSData dataWithBytesNoCopy:__MRAID_mraid_js
                                               length:__MRAID_mraid_js_len
                                         freeWhenDone:NO];
    self.mraidjs = [[NSString alloc] initWithData:mraidJSData encoding:NSUTF8StringEncoding];
    mraidJSData = nil;
    
    if (self.mraidjs) {
        [self injectJavaScript:self.mraidjs];
    }
    
    [self intersectJsLog];
    
    html = [SKMRAIDUtil processRawHtml:html];
    if (html) {
        self.state = MRAIDStateLoading;
        [self.currentWebView loadHTMLString:html baseURL:self.baseURL];
    } else {
        if ([self.delegate respondsToSelector:@selector(mraidView:failToLoadAdThrowError:)]) {
            NSError * error = [NSError errorWithDomain:kSKMRAIDErrorDomain code:MRAIDValidationError userInfo:nil];
            [self.delegate mraidView:self failToLoadAdThrowError:error];
        }
    }
}

- (void)cancel
{
    [self.currentWebView stopLoading];
    self.currentWebView = nil;
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}


#pragma mark - Designated initializer

- (instancetype)initWithFrame:(CGRect)frame
               asInterstitial:(BOOL)isInter
            supportedFeatures:(NSArray *)currentFeatures
                     delegate:(id<SKMRAIDViewDelegate>)delegate
              serviceDelegate:(id<SKMRAIDServiceDelegate>)serviceDelegate
                customScripts:(NSArray *)customScripts
           rootViewController:(UIViewController *)rootViewController {
    
    self = [super initWithFrame:frame];
    if (self) {
        [self setUpTapGestureRecognizer];
        self.isInterstitial = isInter;
        _delegate = delegate;
        _serviceDelegate = serviceDelegate;
        _rootViewController = rootViewController;
        _estimatedAdSize = CGSizeZero;
        
        self.customScripts = customScripts;
        self.state = MRAIDStateDefault;
        self.isViewable = NO;
        
        self.orientationProperties = [[SKMRAIDOrientationProperties alloc] init];
        self.resizeProperties = [[SKMRAIDResizeProperties alloc] init];
        
        self.mraidParser = [[SKMRAIDParser alloc] init];
        
        self.mraidFeatures = @[
                          MRAIDSupportsSMS,
                          MRAIDSupportsTel,
                          MRAIDSupportsCalendar,
                          MRAIDSupportsStorePicture,
                          MRAIDSupportsInlineVideo,
                          ];
        
        if([self isValidFeatureSet:currentFeatures] && serviceDelegate){
            self.supportedFeatures=currentFeatures;
        }
        
        self.previousMaxSize = CGSizeZero;
        self.previousScreenSize = CGSizeZero;
        
        [self addObserver:self forKeyPath:@"self.frame" options:NSKeyValueObservingOptionOld context:NULL];
    }
    return self;
}

#pragma mark - Private


- (void)dealloc
{
    
    [self removeObserver:self forKeyPath:@"self.frame"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    self.webView = nil;
    self.webViewPart2 = nil;
    self.currentWebView = nil;
    
    self.mraidParser = nil;
    self.modalVC = nil;
    
    self.orientationProperties = nil;
    self.resizeProperties = nil;
    
    self.mraidFeatures = nil;
    self.supportedFeatures = nil;
    
    self.closeEventRegion = nil;
    self.resizeView = nil;
    self.resizeCloseRegion = nil;
    
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
            return NO;
        }
    }
    return YES;
}

- (void)setIsViewable:(BOOL)isViewable
{
    _isViewable=isViewable;
    
    WKUserContentController * controller = self.currentWebView.configuration.userContentController;
    if (isViewable) {
        [self removeScriptMessageHandlerInController:controller];
        [self addScriptMessageHandlerToController:controller];
    } else {
        [self removeScriptMessageHandlerInController:controller];
    }
    
    [self fireViewableChangeEvent];
}

- (void)setRootViewController:(UIViewController *)newRootViewController
{
    if(newRootViewController!=_rootViewController) {
        _rootViewController=newRootViewController;
    }
}

- (void)deviceOrientationDidChange:(NSNotification *)notification
{
    [self setScreenSize];
    [self setMaxSize];
    [self setDefaultPosition];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (!([keyPath isEqualToString:@"self.frame"])) {
        return;
    }
    
    CGRect oldFrame = CGRectNull;
    CGRect newFrame = CGRectNull;
    if (change[@"old"] != [NSNull null]) {
        oldFrame = [change[@"old"] CGRectValue];
    }
    if ([object valueForKeyPath:keyPath] != [NSNull null]) {
        newFrame = [[object valueForKeyPath:keyPath] CGRectValue];
    }
    
    if (self.state == MRAIDStateResized) {
        [self setResizeViewPosition];
    }
    [self setDefaultPosition];
    [self setMaxSize];
    [self fireSizeChangeEvent];
}

-(void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    self.currentWebView.backgroundColor = backgroundColor;
}

#pragma mark - interstitial support

- (void)showAsInterstitial
{
    [self expand:nil];
}

#pragma mark - JavaScript --> native support

// These methods are (indirectly) called by JavaScript code.
// They provide the means for JavaScript code to talk to native code

- (void)close
{
    if (self.state == MRAIDStateLoading ||
        (self.state == MRAIDStateDefault && !self.isInterstitial) ||
        self.state == MRAIDStateHidden) {
        // do nothing
        return;
    }
    
    if (self.state == MRAIDStateResized) {
        [self closeFromResize];
        return;
    }
    
    if (self.modalVC) {
        [self.closeEventRegion removeFromSuperview];
        self.closeEventRegion = nil;
        [self.currentWebView removeFromSuperview];
        [self.modalVC dismissViewControllerAnimated:NO completion:nil];
    }
    
    self.modalVC = nil;
    
    if (self.webViewPart2) {
        // Clean up webViewPart2 if returning from 2-part expansion.
        self.webViewPart2.navigationDelegate = nil;
        self.currentWebView = self.webView;
        self.webViewPart2 = nil;
    } else {
        // Reset frame of webView if returning from 1-part expansion.
        self.webView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    }
    
    [self addSubview:self.webView];
    
    if (!self.isInterstitial) {
        [self fireSizeChangeEvent];
    } else {
        self.isViewable = NO;
        [self fireViewableChangeEvent];
    }
    
    if (self.state == MRAIDStateDefault && self.isInterstitial) {
        self.state = MRAIDStateHidden;
    } else if (self.state == MRAIDStateExpanded || self.state == MRAIDStateResized) {
        self.state = MRAIDStateDefault;
    }
    [self fireStateChangeEvent];
    
    if ([self.delegate respondsToSelector:@selector(mraidViewDidClose:)]) {
        [self.delegate mraidViewDidClose:self];
    }
}

// This is a helper method which is not part of the official MRAID API.
- (void)closeFromResize
{
    [self removeResizeCloseRegion];
    self.state = MRAIDStateDefault;
    [self fireStateChangeEvent];
    [self.webView removeFromSuperview];
    self.webView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    [self addSubview:self.webView];
    [self.resizeView removeFromSuperview];
    self.resizeView = nil;
    [self fireSizeChangeEvent];
    if ([self.delegate respondsToSelector:@selector(mraidViewDidClose:)]) {
        [self.delegate mraidViewDidClose:self];
    }
}

- (void)createCalendarEvent:(NSString *)eventJSON
{
    if(!self.bonafideTapObserved && SK_SUPPRESS_BANNER_AUTO_REDIRECT){
        return;  // ignore programmatic touches (taps)
    }

    eventJSON=[eventJSON stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    if ([self.supportedFeatures containsObject:MRAIDSupportsCalendar]) {
        if ([self.serviceDelegate respondsToSelector:@selector(mraidServiceCreateCalendarEventWithEventJSON:)]) {
            [self.serviceDelegate mraidServiceCreateCalendarEventWithEventJSON:eventJSON];
        }
    }
}

// Note: This method is also used to present an interstitial ad.
- (void)expand:(NSString *)urlString
{
    if((!self.bonafideTapObserved && SK_SUPPRESS_BANNER_AUTO_REDIRECT) && !self.isInterstitial){
        return;  // ignore programmatic touches (taps)
    }
    
    // The only time it is valid to call expand is when the ad is currently in either default or resized state.
    if (self.state != MRAIDStateDefault && self.state != MRAIDStateResized) {
        // do nothing
        return;
    }
    
    self.modalVC = [[SKMRAIDModalViewController alloc] initWithOrientationProperties:self.orientationProperties];
    CGRect frame = [[UIScreen mainScreen] bounds];
    self.modalVC.view.frame = frame;
    self.modalVC.delegate = self;
    
    if (!urlString) {
        // 1-part expansion
        self.webView.frame = frame;
        [self.webView removeFromSuperview];
    } else {
        // 2-part expansion
        self.webViewPart2 = [self defaultWebViewWithFrame:frame];
        self.currentWebView = self.webViewPart2;
        self.bonafideTapObserved = YES; // by definition for 2 part expand a valid tap has occurred
        
        if (self.mraidjs) {
            [self injectJavaScript:self.mraidjs];
        }
        
        // Check to see whether we've been given an absolute or relative URL.
        // If it's relative, prepend the base URL.
        urlString = [urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (![[NSURL URLWithString:urlString] scheme]) {
            // relative URL
            urlString = [[[self.baseURL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByAppendingString:urlString];
        }
        
        // Need to escape characters which are URL specific
        urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSError *error;
        NSString *content = [NSString stringWithContentsOfURL:[NSURL URLWithString:urlString] encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            [self.webViewPart2 loadHTMLString:content baseURL:self.baseURL];
        } else {
            // Error! Clean up and return.
            self.currentWebView = self.webView;
            self.webViewPart2.navigationDelegate = nil;
            self.webViewPart2 = nil;
            self.modalVC = nil;
            return;
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(mraidViewWillExpand:)]) {
        [self.delegate mraidViewWillExpand:self];
    }
    
    [self.modalVC.view addSubview:self.currentWebView];
    [self layoutWebView:self.currentWebView inView:self.modalVC.view];
    
    if (SK_SUPPRESS_BANNER_AUTO_REDIRECT) {
        [self.modalVC setTapObserver];
    }
    // always include the close event region
    [self addCloseEventRegion];
    
   
    // used if running >= iOS 6
    if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {  // respect clear backgroundColor
        self.rootViewController.navigationController.modalPresentationStyle = UIModalPresentationCurrentContext;
    } else {
        self.modalVC.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    
    [self.rootViewController presentViewController:self.modalVC animated:NO completion:^{
        if (!self.isInterstitial) {
            self.state = MRAIDStateExpanded;
            [self fireStateChangeEvent];
        }
        [self fireSizeChangeEvent];
        self.isViewable = YES;
    }];
}

- (void)layoutWebView:(UIView *)webView inView:(UIView *)view {
    if (CGSizeEqualToSize(self.estimatedAdSize, CGSizeZero)) {
        return;
    }
    webView.hidden = YES;
    webView.frame = CGRectMake(.0f, 0.0f, self.estimatedAdSize.width, self.estimatedAdSize.height);
    webView.center = view.center;
    webView.hidden = NO;
}

- (void)open:(NSString *)urlString
{
    if(!self.bonafideTapObserved && SK_SUPPRESS_BANNER_AUTO_REDIRECT){
       return;  // ignore programmatic touches (taps)
    }
    
    urlString = [urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    // Notify the callers
    if ([self.delegate respondsToSelector:@selector(mraidViewNavigate:withURL:)]) {
        [self.delegate mraidViewNavigate:self withURL:[NSURL URLWithString:urlString]];
    }
}

- (void)playVideo:(NSString *)urlString
{
    if(!self.bonafideTapObserved && SK_SUPPRESS_BANNER_AUTO_REDIRECT){
        NSString * pauseVideoScript = @"var video = document.querySelector('video');\
                                        video.pause();";
        [self.currentWebView evaluateJavaScript:pauseVideoScript completionHandler:nil];
        return;  // ignore programmatic touches (taps)
    }
    
    urlString = [urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if ([self.serviceDelegate respondsToSelector:@selector(mraidServicePlayVideoWithUrlString:)]) {
        [self.serviceDelegate mraidServicePlayVideoWithUrlString:urlString];
    }
}

- (void)resize
{
    if(!self.bonafideTapObserved && SK_SUPPRESS_BANNER_AUTO_REDIRECT){
        return;  // ignore programmatic touches (taps)
    }
    
    // If our delegate doesn't respond to the mraidViewShouldResizeToPosition:allowOffscreen: message,
    // then we can't do anything. We need help from the app here.
    if (![self.delegate respondsToSelector:@selector(mraidViewShouldResize:toPosition:allowOffscreen:)]) {
        return;
    }
    
    CGRect resizeFrame = CGRectMake(self.resizeProperties.offsetX, self.resizeProperties.offsetY, self.resizeProperties.width, self.resizeProperties.height);
    // The offset of the resize frame is relative to the origin of the default banner.
    CGPoint bannerOriginInRootView = [self.rootViewController.view convertPoint:CGPointZero fromView:self];
    resizeFrame.origin.x += bannerOriginInRootView.x;
    resizeFrame.origin.y += bannerOriginInRootView.y;
    
    if (![self.delegate mraidViewShouldResize:self toPosition:resizeFrame allowOffscreen:self.resizeProperties.allowOffscreen]) {
        return;
    }
    
    // resize here
    self.state = MRAIDStateResized;
    [self fireStateChangeEvent];
    
    if (!self.resizeView) {
        self.resizeView = [[UIView alloc] initWithFrame:resizeFrame];
        [self.webView removeFromSuperview];
        [self.resizeView addSubview:self.webView];
        [self.rootViewController.view addSubview:self.resizeView];
    }
    
    self.resizeView.frame = resizeFrame;
    self.webView.frame = self.resizeView.bounds;
    [self showResizeCloseRegion];
    [self fireSizeChangeEvent];
}

- (void)setOrientationProperties:(NSDictionary *)properties;
{
    BOOL allowOrientationChange = [[properties valueForKey:@"allowOrientationChange"] boolValue];
    NSString *forceOrientation = [properties valueForKey:@"forceOrientation"];
    self.orientationProperties.allowOrientationChange = allowOrientationChange;
    self.orientationProperties.forceOrientation = [SKMRAIDOrientationProperties MRAIDForceOrientationFromString:forceOrientation];
    [self.modalVC forceToOrientation:self.orientationProperties];
}

- (void)setResizeProperties:(NSDictionary *)properties;
{
    int width = [[properties valueForKey:@"width"] intValue];
    int height = [[properties valueForKey:@"height"] intValue];
    int offsetX = [[properties valueForKey:@"offsetX"] intValue];
    int offsetY = [[properties valueForKey:@"offsetY"] intValue];
    NSString *customClosePosition = [properties valueForKey:@"customClosePosition"];
    BOOL allowOffscreen = [[properties valueForKey:@"allowOffscreen"] boolValue];
    self.resizeProperties.width = width;
    self.resizeProperties.height = height;
    self.resizeProperties.offsetX = offsetX;
    self.resizeProperties.offsetY = offsetY;
    self.resizeProperties.customClosePosition = [SKMRAIDResizeProperties MRAIDCustomClosePositionFromString:customClosePosition];
    self.resizeProperties.allowOffscreen = allowOffscreen;
}

-(void)storePicture:(NSString *)urlString
{
    if(!self.bonafideTapObserved && SK_SUPPRESS_BANNER_AUTO_REDIRECT){
        return;  // ignore programmatic touches (taps)
    }
    
    urlString=[urlString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    if ([self.supportedFeatures containsObject:MRAIDSupportsStorePicture]) {
        if ([self.serviceDelegate respondsToSelector:@selector(mraidServiceStorePictureWithUrlString:)]) {
            [self.serviceDelegate mraidServiceStorePictureWithUrlString:urlString];
        }
    }
}

- (void)useCustomClose:(NSString *)isCustomCloseString
{
    BOOL isCustomClose = [isCustomCloseString boolValue];
    self.useCustomClose = isCustomClose;
}

- (void)loaded {
    [self.doubleClickDelegate doubleClickAdReady];
}

- (void)noFill {
    [self.doubleClickDelegate doubleClickNoFill];
}

#pragma mark - JavaScript --> native support helpers

// These methods are helper methods for the ones above.

- (UIImage *)defaultCloseButtonImage {
    NSData* buttonData = [NSData dataWithBytesNoCopy:__MRAID_CloseButton_png
                                              length:__MRAID_CloseButton_png_len
                                        freeWhenDone:NO];
    UIImage * closeButtonImage = [UIImage imageWithData:buttonData];
    return closeButtonImage;
}

- (void)addCloseEventRegion
{
    if ([self.delegate respondsToSelector:@selector(mraidView:requierToUseCustomCloseInView:)]) {
        [self.delegate mraidView:self requierToUseCustomCloseInView:self.modalVC.view];
        return;
    }
    
    self.closeEventRegion = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeEventRegion.backgroundColor = [UIColor clearColor];
    [self.closeEventRegion addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    
    [self.closeEventRegion setBackgroundImage: [self defaultCloseButtonImage] forState:UIControlStateNormal];
    
    self.closeEventRegion.frame = CGRectMake(0, 0, kCloseEventRegionSize, kCloseEventRegionSize);
    
    CGRect frame = self.closeEventRegion.frame;
    self.closeEventRegion.sk_hitTestEdgeInsets = UIEdgeInsetsMake(kCloseEventRegionInset, kCloseEventRegionInset, kCloseEventRegionInset, kCloseEventRegionInset);
    
    // align on top right
    int x = CGRectGetWidth(self.modalVC.view.frame) - CGRectGetWidth(frame);
    frame.origin = CGPointMake(x, kStatusBarOffset);
    self.closeEventRegion.frame = frame;
    // autoresizing so it stays at top right (flexible left and flexible bottom margin)
    self.closeEventRegion.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.modalVC.view addSubview:self.closeEventRegion];
}

- (void)showResizeCloseRegion
{
    if (!self.resizeCloseRegion) {
        self.resizeCloseRegion = [UIButton buttonWithType:UIButtonTypeCustom];
        self.resizeCloseRegion.frame = CGRectMake(0, 0, kCloseEventRegionSize, kCloseEventRegionSize);
        self.resizeCloseRegion.backgroundColor = [UIColor clearColor];
        [self.resizeCloseRegion addTarget:self action:@selector(closeFromResize) forControlEvents:UIControlEventTouchUpInside];
        [self.resizeView addSubview:self.resizeCloseRegion];
    }
    
    // align appropriately
    int x;
    int y;
    UIViewAutoresizing autoresizingMask = UIViewAutoresizingNone;
    
    switch (self.resizeProperties.customClosePosition) {
        case MRAIDCustomClosePositionTopLeft:
        case MRAIDCustomClosePositionBottomLeft:
            x = 0;
            break;
        case MRAIDCustomClosePositionTopCenter:
        case MRAIDCustomClosePositionCenter:
        case MRAIDCustomClosePositionBottomCenter:
            x = (CGRectGetWidth(self.resizeView.frame) - CGRectGetWidth(self.resizeCloseRegion.frame)) / 2;
            autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
            break;
        case MRAIDCustomClosePositionTopRight:
        case MRAIDCustomClosePositionBottomRight:
            x = CGRectGetWidth(self.resizeView.frame) - CGRectGetWidth(self.resizeCloseRegion.frame);
            autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            break;
    }
    
    switch (self.resizeProperties.customClosePosition) {
        case MRAIDCustomClosePositionTopLeft:
        case MRAIDCustomClosePositionTopCenter:
        case MRAIDCustomClosePositionTopRight:
            y = 0;
            break;
        case MRAIDCustomClosePositionCenter:
            y = (CGRectGetHeight(self.resizeView.frame) - CGRectGetHeight(self.resizeCloseRegion.frame)) / 2;
            autoresizingMask |= UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            break;
        case MRAIDCustomClosePositionBottomLeft:
        case MRAIDCustomClosePositionBottomCenter:
        case MRAIDCustomClosePositionBottomRight:
            y = CGRectGetHeight(self.resizeView.frame) - CGRectGetHeight(self.resizeCloseRegion.frame);
            autoresizingMask |= UIViewAutoresizingFlexibleTopMargin;
            break;
    }
    
    CGRect resizeCloseRegionFrame = self.resizeCloseRegion.frame;
    resizeCloseRegionFrame.origin = CGPointMake(x, y);
    self.resizeCloseRegion.frame = resizeCloseRegionFrame;
    self.resizeCloseRegion.autoresizingMask = autoresizingMask;
}

- (void)removeResizeCloseRegion
{
    if (self.resizeCloseRegion) {
        [self.resizeCloseRegion removeFromSuperview];
        self.resizeCloseRegion = nil;
    }
}

- (void)setResizeViewPosition
{
    CGRect oldResizeFrame = self.resizeView.frame;
    CGRect newResizeFrame = CGRectMake(self.resizeProperties.offsetX, self.resizeProperties.offsetY, self.resizeProperties.width, self.resizeProperties.height);
    // The offset of the resize frame is relative to the origin of the default banner.
    CGPoint bannerOriginInRootView = [self.rootViewController.view convertPoint:CGPointZero fromView:self];
    newResizeFrame.origin.x += bannerOriginInRootView.x;
    newResizeFrame.origin.y += bannerOriginInRootView.y;
    if (!CGRectEqualToRect(oldResizeFrame, newResizeFrame)) {
        self.resizeView.frame = newResizeFrame;
    }
}

#pragma mark - native -->  JavaScript support

- (void)injectJavaScript:(NSString *)js
{
    [self.currentWebView evaluateJavaScript:js completionHandler:nil];
//    [self.currentWebView evaluateJavaScript:js completionHandler:^(id _Nullable callback, NSError * _Nullable error) {
//        NSLog(@"Callback %@ \n Error: %@", callback, error);
//    }];
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
    int x;
    int y;
    int width;
    int height;
    if (self.state == MRAIDStateExpanded || self.isInterstitial) {
        x = (int)self.currentWebView.frame.origin.x;
        y = (int)self.currentWebView.frame.origin.y;
        width = (int)self.currentWebView.frame.size.width;
        height = (int)self.currentWebView.frame.size.height;
    } else if (self.state == MRAIDStateResized) {
        x = (int)self.resizeView.frame.origin.x;
        y = (int)self.resizeView.frame.origin.y;
        width = (int)self.resizeView.frame.size.width;
        height = (int)self.resizeView.frame.size.height;
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
    
    BOOL adjustOrientationForIOS8 = self.isInterstitial &&  isLandscape && !SYSTEM_VERSION_LESS_THAN(@"8.0");
    [self injectJavaScript:[NSString stringWithFormat:@"mraid.setCurrentPosition(%d,%d,%d,%d);", x, y, adjustOrientationForIOS8?height:width, adjustOrientationForIOS8?width:height]];
}

- (void)fireStateChangeEvent
{
    NSArray *stateNames = @[
                            @"loading",
                            @"default",
                            @"expanded",
                            @"resized",
                            @"hidden",
                            ];
    
    NSString *stateName = stateNames[self.state];
    [self injectJavaScript:[NSString stringWithFormat:@"mraid.fireStateChangeEvent('%@');", stateName]];
    
}

- (void)fireViewableChangeEvent
{
    [self injectJavaScript:[NSString stringWithFormat:@"mraid.fireViewableChangeEvent(%@);", (self.isViewable ? @"true" : @"false")]];
}

- (void)setDefaultPosition
{
    if (self.isInterstitial) {
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
    if (self.isInterstitial) {
        // For interstitials, we define maxSize to be the same as screen size, so set the value there.
        return;
    }
    CGSize maxSize = self.rootViewController.view.bounds.size;
    if (!CGSizeEqualToSize(maxSize, self.previousMaxSize)) {
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.setMaxSize(%d,%d);",
                                (int)maxSize.width,
                                (int)maxSize.height]];
        self.previousMaxSize = CGSizeMake(maxSize.width, maxSize.height);
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
   
    CGFloat scale = [UIScreen mainScreen].scale;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        screenSize = CGSizeMake(screenSize.width * scale, screenSize.height * scale);
    } else {
        if (isLandscape) {
            screenSize = CGSizeMake(screenSize.height * scale, screenSize.width * scale);
        }
    }
    if (!CGSizeEqualToSize(screenSize, self.previousScreenSize)) {
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.setScreenSize(%d,%d);",
                                (int)screenSize.width,
                                (int)screenSize.height]];
        self.previousScreenSize = CGSizeMake(screenSize.width, screenSize.height);
        if (self.isInterstitial) {
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
    for (id aFeature in self.mraidFeatures) {
            [self injectJavaScript:[NSString stringWithFormat:@"mraid.setSupports('%@',%@);", aFeature,[currentFeatures containsObject:aFeature]?@"true":@"false"]];
    }
}


#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self disableJsCallbackInWebViewIfNeeded:webView];
    
    if (self.state == MRAIDStateLoading) {
        self.state = MRAIDStateDefault;
        [self injectJavaScript:[NSString stringWithFormat:@"mraid.setPlacementType('%@');", (self.isInterstitial ? @"interstitial" : @"inline")]];
        [self setSupports:self.supportedFeatures];
        [self setDefaultPosition];
        [self setMaxSize];
        [self setScreenSize];
        [self fireStateChangeEvent];
        [self fireSizeChangeEvent];
        [self fireReadyEvent];
        [self disableFullscreenVideoInWebView:webView];
        
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

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(mraidView:failToLoadAdThrowError:)]) {
        NSError * mraidError = [NSError errorWithDomain:kSKMRAIDErrorDomain code:MRAIDShowError userInfo:error.userInfo];
        [self.delegate mraidView:self failToLoadAdThrowError:mraidError];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    WKNavigationActionPolicy policy = WKNavigationActionPolicyCancel;
    NSString * request = navigationAction.request.URL.absoluteString;
    
    if (self.state == MRAIDStateLoading) {
        if ([request containsString:@"about:blank"] ||
            [request containsString:@"http://"] ||
            [request containsString:@"https://"]) {
            
            policy = WKNavigationActionPolicyAllow;
        }
    }
    
    if (self.state == MRAIDStateDefault) {
        if (_bonafideTapObserved && (navigationAction.navigationType == WKNavigationTypeLinkActivated ||
                                     navigationAction.navigationType == WKNavigationTypeOther)) {
            if ([self.delegate respondsToSelector:@selector(mraidViewNavigate:withURL:)]) {
                [self.delegate mraidViewNavigate:self withURL:navigationAction.request.URL];
            }
        } else {
            NSString * scheme = navigationAction.request.URL.scheme;
            BOOL iframe = ![navigationAction.request.URL isEqual:navigationAction.request.mainDocumentURL];
            
            // If we load a URL from an iFrame that did not originate from a click or
            // is a deep link, handle normally and return safeToAutoloadLink.
            if (iframe && !((navigationAction.navigationType == WKNavigationTypeLinkActivated) && ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]))) {
                BOOL safeToAutoload = navigationAction.navigationType == WKNavigationTypeLinkActivated ||
                _bonafideTapObserved ||
                [scheme isEqualToString:@"https"] ||
                [scheme isEqualToString:@"http"];
                
                policy = safeToAutoload ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel;
            }
        }
    }
    
    decisionHandler(policy);
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSString * observer = message.name;
    
    if ([observer isEqualToString:kLogHandlerName]) {
        if ([self.delegate respondsToSelector:@selector(mraidView:intersectJsLogMessage:)]) {
            [self.delegate mraidView:self intersectJsLogMessage:message.body];
        }
    } else if ([observer isEqualToString:kScriptObserverName]) {
        [self parseCommandUrl:message.body];
    }
}

#pragma mark - WKUIDelegate

- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    
    if (self.state == MRAIDStateDefault) {
        NSString * scheme = navigationAction.request.URL.scheme;
        BOOL isHttpLink = [scheme isEqualToString:@"https"] ||
                          [scheme isEqualToString:@"http"];
        
        BOOL safeToAutoload = navigationAction.navigationType == WKNavigationTypeLinkActivated ||
                              navigationAction.navigationType == WKNavigationTypeOther;

        if (_bonafideTapObserved && isHttpLink && safeToAutoload) {
            if ([self.delegate respondsToSelector:@selector(mraidViewNavigate:withURL:)]) {
                [self.delegate mraidViewNavigate:self withURL:navigationAction.request.URL];
            }
        }
    }
    return nil;
}

#pragma mark - MRAIDModalViewControllerDelegate

- (void)mraidModalViewControllerDidRotate:(SKMRAIDModalViewController *)modalViewController {
    [self layoutWebView:self.currentWebView inView:modalViewController.view];
    [self setScreenSize];
    [self fireSizeChangeEvent];
}

- (void)mraidModalViewControllerDidRecieveTap:(SKMRAIDModalViewController *)modalViewController {
    [self oneFingerOneTap];
    [modalViewController removeTapObserver];
}

#pragma mark - internal helper methods

- (WKWebView *)defaultWebViewWithFrame:(CGRect)frame {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    if ([self.supportedFeatures containsObject:MRAIDSupportsInlineVideo]) {
        configuration.allowsInlineMediaPlayback = YES;
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")) {
            configuration.requiresUserActionForMediaPlayback = self.isInterstitial;
        } else {
            configuration.mediaPlaybackRequiresUserAction = self.isInterstitial;
        }
    } else {
        configuration.allowsInlineMediaPlayback = NO;
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")) {
            configuration.requiresUserActionForMediaPlayback = self.isInterstitial;
        } else {
            configuration.mediaPlaybackRequiresUserAction = self.isInterstitial;
        }
    }
    
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = NO;
    
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    configuration.userContentController = controller;
    
    [self.customScripts enumerateObjectsUsingBlock:^(WKUserScript * _Nonnull script, NSUInteger idx, BOOL * _Nonnull stop) {
        [controller addUserScript:script];
    }];
    
    [self addScriptMessageHandlerToController:controller];
    WKWebView * wv = [[WKWebView alloc] initWithFrame:frame configuration:configuration];
    
    wv.navigationDelegate = self;
    wv.UIDelegate = self;
    wv.opaque = NO;
    wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    wv.autoresizesSubviews = YES;
    
    // disable scrolling
    UIScrollView *scrollView = [wv scrollView];
    scrollView.scrollEnabled = NO;
    
    // disable selection
    NSString *js = @"window.getSelection().removeAllRanges();";
    [wv evaluateJavaScript:js completionHandler:^(id _Nullable callback, NSError * _Nullable error) {
        //TODO:
    }];
    // Alert suppression
    [self disableJsCallbackInWebViewIfNeeded:wv];
    
    return wv;
}

- (void)intersectJsLog {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0")) {  
        NSString *script = @"console = new Object(); \n" \
        "console.log = function(log) { \n" \
        "   window.webkit.messageHandlers.logHandler.postMessage(log); \n" \
        "}; \n" \
        "console.debug = console.log; \n" \
        "console.info = console.log; \n" \
        "console.warn = console.log; \n" \
        "console.error = console.log;";
        
        [self injectJavaScript:script];
    }
}

- (NSArray *)scriptMessageHandlersNames {
    return @[kScriptObserverName, kLogHandlerName];
}

- (void)addScriptMessageHandlerToController:(WKUserContentController *)controller {
    [self.scriptMessageHandlersNames enumerateObjectsUsingBlock:^(NSString * name, NSUInteger idx, BOOL * _Nonnull stop) {
        [controller addScriptMessageHandler:self name:name];
    }];
}

- (void)removeScriptMessageHandlerInController:(WKUserContentController *)controller {
    [self.scriptMessageHandlersNames enumerateObjectsUsingBlock:^(NSString * name, NSUInteger idx, BOOL * _Nonnull stop) {
        [controller removeScriptMessageHandlerForName:name];
    }];
}

- (void)disableJsCallbackInWebViewIfNeeded:(WKWebView *)webView {
    if (SK_SUPPRESS_JS_ALERT) {
        NSString * disableJSAlertScript = @"function alert(){}; function prompt(){}; function confirm(){}";
        [webView evaluateJavaScript:disableJSAlertScript completionHandler:^(id _Nullable callback, NSError * _Nullable error) {
            //TODO:
        }];
    }
}

- (void)disableFullscreenVideoInWebView:(WKWebView *)webView {
    NSString * disableFullScreenAutoplaySript = @"var video = document.querySelector('video');\
    video.setAttribute('webkit-playsinline', true);\
    video.setAttribute('playsinline', true);\
    video.setAttribute('muted', true);\
    video.addEventListener('playing', mraid.playVideo)";
    
    [webView evaluateJavaScript:disableFullScreenAutoplaySript completionHandler:nil];
}

- (void)parseCommandUrl:(NSString *)commandUrlString
{
    NSDictionary *commandDict = [self.mraidParser parseCommandUrl:commandUrlString];
    if (!commandDict) {
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

#pragma mark - Gesture Methods

- (void)setUpTapGestureRecognizer
{
    if(!SK_SUPPRESS_BANNER_AUTO_REDIRECT){
        return;  // return without adding the GestureRecognizer if the feature is not enabled
    }
    // One finger, one tap
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(oneFingerOneTap)];
    
    // Set up
    [self.tapGestureRecognizer setNumberOfTapsRequired:1];
    [self.tapGestureRecognizer setNumberOfTouchesRequired:1];
    [self.tapGestureRecognizer setDelegate:self];
    
    // Add the gesture to the view
    [self addGestureRecognizer:self.tapGestureRecognizer];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;   // required to allow UIWebview to work correctly, see  http://stackoverflow.com/questions/2909807/does-uigesturerecognizer-work-on-a-uiwebview
}

-(void)oneFingerOneTap
{
    self.bonafideTapObserved=YES;
    self.tapGestureRecognizer.delegate=nil;
    self.tapGestureRecognizer=nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (touch.view == self.resizeCloseRegion || touch.view == self.closeEventRegion){
        return NO;
    }
    return YES;
}

@end
