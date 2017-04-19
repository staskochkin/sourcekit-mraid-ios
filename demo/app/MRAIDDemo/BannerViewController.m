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
    
//    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:self.htmlFile ofType:@"html"];
//    NSString* htmlData = [[NSString alloc] initWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    NSURL * url = [NSURL URLWithString:@"http://x.appodeal.com/request/banner?ad_space_id=1&dm_ver=2.0.0&bidfloor=0.1&ifa=5368CDB5-2480-40D8-A38C-9C1F1BC2630A&ip=77.72.140.9&ua=Mozilla/5.0%20(iPhone;%20CPU%20iPhone%20OS%2010_2%20like%20Mac%20OS%20X)%20AppleWebKit/602.3.12%20(KHTML,%20like%20Gecko)%20Mobile/14C89&osv=10.2&os=ios&h=568&w=320&devicetype=4&make=Apple&model=x86_64&zip=613043&utcoffset=180&country=RUS&ver=4.0&external_app_id=7635&publisher_id=1&native_ad_type=banner_320&coppa=0&lmt=0&hwv=x86_64&lat=58.5539&lon=50.0399&geo_type=2&connectiontype=2&gender=O&age=0&alcohol=0&occupation=0&relation=0&smoking=0&device_ext=%7B%22battery%22:-100,%22rooted%22:%22false%22%7D&app_ext=%7B%22sdk%22:%222.0.0%22,%22session_uptime%22:73,%22session_id%22:11,%22app_uptime%22:78,%22impressions_count%22:16,%22clicks_count%22:2%7D&ppi=326&pxratio=2.000000"];
    [self.adView preloadAdFromURL:url];
    
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
