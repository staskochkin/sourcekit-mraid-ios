//
//  BannerViewController.m
//  MRAIDDemo
//
//  Created by Muthu on 9/25/13.
//  Copyright (c) 2013 Nexage. All rights reserved.
//

#import "BannerViewController.h"
#import "SKMRAIDView.h"
#import "SKMRAIDServiceDelegate.h"
#import <WebKit/WebKit.h>


@interface BannerViewController () <SKMRAIDViewDelegate, SKMRAIDServiceDelegate>

@property (retain, nonatomic) SKMRAIDView *adView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *creativeLabel;

@end

@implementation BannerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Make sure that you fill properties needed to identify creative
    self.titleLabel.text = self.titleText;
    self.creativeLabel.text = [NSString stringWithFormat:@"Ad: %@.html", self.htmlFile];
    NSString *additionInfoText = NSLocalizedString(self.htmlFile, @"");
    if (![additionInfoText isEqualToString:self.htmlFile])
    {
        self.additionalInfo.text = additionInfoText;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)loadCreativeOnABanner
{
    // Type 1
    
    
    // Type 2
    //    NSString* htmlData = @"<html><body align='center'>Hello World<br/><button type='button' onclick='alert(mraid.getVersion());'>Get Version</button></body></html>";
    
    // Type 3 - If you want to point to a URL
    //    NSString* htmlData = [[NSString alloc] initWithContentsOfURL:[NSURL URLWithString:@"http://files.nexage.com/testads/SDK/mraid/banner.expand.1-part.fullHtml.html"] encoding:NSUTF8StringEncoding error:nil];

 
    // Initialize and load the MRAIDView
    WKUserScript * script = [[WKUserScript alloc] initWithSource:@"console.log('Hello from JS!')"
                                                   injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                forMainFrameOnly:NO];
    NSArray * scripts = [NSArray arrayWithObject:script];
    
    self.adView = [[SKMRAIDView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)
                                   supportedFeatures:@[MRAIDSupportsSMS, MRAIDSupportsTel, MRAIDSupportsCalendar, MRAIDSupportsStorePicture, MRAIDSupportsInlineVideo]
                                            delegate:self
                                     serviceDelegate:self
                                       customScripts:scripts
                                  rootViewController:self];
    
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:self.htmlFile ofType:@"html"];
    NSString* htmlData = [[NSString alloc] initWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    [self.adView loadAdHTML:htmlData];
    
    self.adView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:self.adView];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self centerBannerView];
    [self.adView injectJavaScript:@"console.log('Rotate')"];

}

- (void)viewDidAppear:(BOOL)animated {
    [self centerBannerView];
}

- (void)centerBannerView
{
    CGSize size = self.adView.frame.size;
    CGFloat centeredX = (self.view.bounds.size.width - size.width) / 2;
    self.adView.frame = CGRectMake(centeredX, 0, size.width, size.height);
}

#pragma mark - MRAIDViewDelegate

- (void)mraidView:(SKMRAIDView *)mraidView preloadedAd:(NSString *)preloadedAd {
    [self.adView loadAdHTML:preloadedAd];
}

- (void)mraidViewAdReady:(SKMRAIDView *)mraidView
{
    NSLog(@"%@ MRAIDViewDelegate %@", [[self class] description], NSStringFromSelector(_cmd));
    if ([self.htmlFile isEqualToString:@"banner.isViewable"]) {
        [self performSelector:@selector(moveOffScreen) withObject:nil afterDelay:5];
    }
    
    mraidView.isViewable = YES;
}

- (void)mraidView:(SKMRAIDView *)mraidView intersectJsLogMessage:(NSString *)logMessage {
    NSLog(@"[JS Message Log]: %@", logMessage);
}

- (void)mraidViewAdFailed:(SKMRAIDView *)mraidView
{
    NSLog(@"%@ MRAIDViewDelegate %@", [[self class] description], NSStringFromSelector(_cmd));
}

- (void)mraidViewWillExpand:(SKMRAIDView *)mraidView
{
    NSLog(@"%@ MRAIDViewDelegate %@", [[self class] description], NSStringFromSelector(_cmd));
}

- (void)mraidViewDidClose:(SKMRAIDView *)mraidView
{
    NSLog(@"%@ MRAIDViewDelegate %@", [[self class] description], NSStringFromSelector(_cmd));
}

- (BOOL)mraidViewShouldResize:(SKMRAIDView *)mraidView toPosition:(CGRect)position allowOffscreen:(BOOL)allowOffscreen
{
    NSLog(@"%@ MRAIDViewDelegate %@%@", [[self class] description], NSStringFromSelector(_cmd), NSStringFromCGRect(position));
    // Insert your code to make any needed adjustments to the resized MRAIDview or its containing view.
    return YES;
}

- (void)mraidViewNavigate:(SKMRAIDView *)mraidView withURL:(NSURL *)url {
    NSLog(@"%@ MRAIDViewDelegate %@ with URL %@", [[self class] description], NSStringFromSelector(_cmd), [url absoluteString]);
}

- (void)mraidView:(SKMRAIDView *)mraidView wasPreloadUrl:(NSURL *)url {
     NSLog(@"%@ MRAIDViewDelegate %@ preload URL %@", [[self class] description], NSStringFromSelector(_cmd), [url absoluteString]);
}

#pragma mark - MRAIDServiceDelegate

- (void)mraidServiceCreateCalendarEventWithEventJSON:(NSString *)eventJSON
{
    NSLog(@"%@ MRAIDServiceDelegate %@%@", [[self class] description], NSStringFromSelector(_cmd), eventJSON);
}

- (void)mraidServiceOpenBrowserWithUrlString:(NSString *)urlString
{
    NSLog(@"%@ MRAIDServiceDelegate %@%@", [[self class] description], NSStringFromSelector(_cmd), urlString);
}

- (void)mraidServicePlayVideoWithUrlString:(NSString *)urlString
{
    NSLog(@"%@ MRAIDServiceDelegate %@%@", [[self class] description], NSStringFromSelector(_cmd), urlString);
    NSURL *videoUrl = [NSURL URLWithString:urlString];
    [[UIApplication sharedApplication] openURL:videoUrl];
}

- (void)mraidServiceStorePictureWithUrlString:(NSString *)urlString
{
    NSLog(@"%@ MRAIDServiceDelegate %@%@", [[self class] description], NSStringFromSelector(_cmd), urlString);
}

#pragma mark - handle isViewable events

-(void)viewWillDisappear:(BOOL)animated
{
    self.adView.isViewable=NO;
}

-(void)viewWillAppear:(BOOL)animated
{
    self.adView.isViewable=YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    self.adView.isViewable=NO;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    self.adView.isViewable=YES;
}

-(BOOL)currentRectOnScreen{
    CGRect windowRect = [[[UIApplication sharedApplication] keyWindow] bounds];
    CGRect currentRect = [self.adView convertRect:self.adView.bounds toView:nil];
    BOOL currentRectOnScreen = CGRectIntersectsRect(windowRect, currentRect);
    NSLog(@"currentRectOnScreen: %@", currentRectOnScreen?@"YES":@"NO");
    return currentRectOnScreen;
}
    
-(void)moveOffScreen
{
    self.adView.frame=CGRectMake(0,-150,320,50);
    [self performSelector:@selector(moveOnScreen) withObject:nil afterDelay:5];
    self.adView.isViewable = [self currentRectOnScreen];
}

-(void)moveOnScreen
{
    self.adView.frame=CGRectMake(0,0,320,50);
    self.adView.isViewable = [self currentRectOnScreen];
}

@end
