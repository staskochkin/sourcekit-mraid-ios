//
//  InterstitialViewController.m
//  MRAIDDemo
//
//  Created by Muthu on 10/18/13.
//  Copyright (c) 2013 Nexage. All rights reserved.
//

#import "InterstitialViewController.h"

#import "SKMRAIDServiceDelegate.h"
#import "SKMRAIDInterstitial.h"
#import <AudioToolbox/AudioToolbox.h>

@interface InterstitialViewController () <SKMRAIDInterstitialDelegate, SKMRAIDServiceDelegate>
{
    SKMRAIDInterstitial *interstitial;
}

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *creativeLabel;

@end

@implementation InterstitialViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
 
    // Make sure that you fill properties needed to identify creative
    self.titleLabel.text = self.titleText;
    self.creativeLabel.text = [NSString stringWithFormat:@"Ad: %@.html", self.htmlFile];
    self.displayInterButton.enabled = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)fetchInterstitial:(id)sender
{
    
//     Type 1
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:self.htmlFile ofType:@"html"];
//    NSURL *bundleUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    NSString* htmlData = [[NSString alloc] initWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    
    // Type 2
    //    NSString* htmlData = @"<html><body align='center'>Hello World<br/><button type='button' onclick='alert(mraid.getVersion());'>Get Version</button></body></html>";
    
    // Type 3 - If you want to point to a URL
    //    NSString* htmlData = [[NSString alloc] initWithContentsOfURL:[NSURL URLWithString:@"http://iab.net/ad.html"] encoding:NSUTF8StringEncoding error:nil];
    

    // Initialize and load the interstitial creative
    NSArray * supportedFeatures = @[MRAIDSupportsSMS, MRAIDSupportsTel, MRAIDSupportsCalendar, MRAIDSupportsStorePicture, MRAIDSupportsInlineVideo];
    
    interstitial = [[SKMRAIDInterstitial alloc] initWithSupportedFeatures:supportedFeatures
                                                                 delegate:self
                                                          serviceDelegate:self
                                                            customScripts:nil
                                                       rootViewController:self];
    
//    NSURL * url = [NSURL URLWithString:@"http://iab.net/ad.html"];
    [interstitial loadAdHTML:htmlData]; //estimatedAdSize:CGSizeMake(300, 250)];
                    
}

- (IBAction)displayInterstitial:(id)sender
{
    NSLog(@"displayInterstitial");
    [interstitial show];
}

#pragma mark - MRAIDInterstitialDelegate

- (void)mraidInterstitial:(SKMRAIDInterstitial *)mraidInterstitial preloadedAd:(NSString *)preloadedAd {
    [interstitial loadAdHTML:preloadedAd];
    
}

- (void)mraidInterstitial:(SKMRAIDInterstitial *)mraidInterstitial didFailToPreloadAd:(NSError *)preloadError {
    
}

- (void)mraidInterstitialAdReady:(SKMRAIDInterstitial *)mraidInterstitial
{
    NSLog(@"%@ MRAIDInterstitialDelegate %@", [[self class] description], NSStringFromSelector(_cmd));
    [self.statusLabel setText:@"Status: Ready"];
    self.fetchInterButton.enabled = NO;
    self.displayInterButton.enabled = YES;
}

- (void)mraidInterstitialAdFailed:(SKMRAIDInterstitial *)mraidInterstitial 
{
    NSLog(@"%@ MRAIDInterstitialDelegate %@", [[self class] description], NSStringFromSelector(_cmd));
}

- (void)mraidInterstitialWillShow:(SKMRAIDInterstitial *)mraidInterstitial
{
    NSLog(@"%@ MRAIDInterstitialDelegate %@", [[self class] description], NSStringFromSelector(_cmd));
}

- (void)mraidInterstitialDidHide:(SKMRAIDInterstitial *)mraidInterstitial
{
    NSLog(@"%@ MRAIDInterstitialDelegate %@", [[self class] description], NSStringFromSelector(_cmd));
    [self.statusLabel setText:@"Status: Not Ready"];
    self.fetchInterButton.enabled = YES;
    self.displayInterButton.enabled = NO;
}

#pragma mark - MRAIDServiceDelegate

- (void)mraidServiceCreateCalendarEventWithEventJSON:(NSString *)eventJSON
{
    NSLog(@"%@ MRAIDServiceDelegate %@%@", [[self class] description], NSStringFromSelector(_cmd), eventJSON);
}

- (void)mraidServiceOpenBrowserWithUrlString:(NSString *)urlString
{
    NSLog(@"%@ MRAIDServiceDelegate %@%@", [[self class] description], NSStringFromSelector(_cmd), urlString);
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
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

- (void)mraidInterstitial:(SKMRAIDInterstitial *)mraidView requierToUseCustomCloseInView:(UIView *)view {
    CGSize imageSize = CGSizeMake(64, 64);
    UIColor *fillColor = [UIColor redColor];
    UIGraphicsBeginImageContextWithOptions(imageSize, YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [fillColor setFill];
    CGContextFillRect(context, CGRectMake(0, 0, imageSize.width, imageSize.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIButton * closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeButton setImage:image forState:UIControlStateNormal];
    [closeButton setFrame:CGRectMake(5, 65, 64, 64)];
    [view addSubview:closeButton];
    [closeButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - handle isViewable events

- (void)close {
    [interstitial close];
}

-(void)viewWillDisappear:(BOOL)animated
{
    NSLog(@"%@ %@", [[self class] description], NSStringFromSelector(_cmd));
   
}

-(void)viewWillAppear:(BOOL)animated
{
    NSLog(@"%@ %@", [[self class] description], NSStringFromSelector(_cmd));
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"%@ %@", [[self class] description], NSStringFromSelector(_cmd));
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"%@ %@", [[self class] description], NSStringFromSelector(_cmd));
}

@end
