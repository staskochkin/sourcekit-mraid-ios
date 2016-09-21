//
//  SKMRAIDModalViewController.m
//  MRAID
//
//  Created by Jay Tucker on 9/20/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import "SKMRAIDModalViewController.h"
#import "MRAIDSettings.h"
#import "SKMRAIDUtil.h"
#import "SKMRAIDOrientationProperties.h"

typedef void (^tapBlock)();

@interface SKMRAIDModalViewController () <UIGestureRecognizerDelegate>
{
    BOOL isStatusBarHidden;
    BOOL hasViewAppeared;
    BOOL hasRotated;
    
    SKMRAIDOrientationProperties *orientationProperties;
    UIInterfaceOrientation preferredOrientation;
}

@property (nonatomic, strong) UITapGestureRecognizer * tapGestureRecognizer;

@end

@implementation SKMRAIDModalViewController

- (id)init
{
    return [self initWithOrientationProperties:nil];
}

- (id)initWithOrientationProperties:(SKMRAIDOrientationProperties *)orientationProps
{
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        if (orientationProps) {
            orientationProperties = orientationProps;
        } else {
            orientationProperties = [[SKMRAIDOrientationProperties alloc] init];
        }
        
        UIInterfaceOrientation currentInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];

        // If the orientation is forced, accomodate it.
        // If it's not fored, then match the current orientation.
        if (orientationProperties.forceOrientation == MRAIDForceOrientationPortrait) {
            preferredOrientation = UIInterfaceOrientationPortrait;
        } else  if (orientationProperties.forceOrientation == MRAIDForceOrientationLandscape) {
            if (UIInterfaceOrientationIsLandscape(currentInterfaceOrientation)) {
                preferredOrientation = currentInterfaceOrientation;
            } else {
                preferredOrientation = UIInterfaceOrientationLandscapeLeft;
            }
        } else {
            // orientationProperties.forceOrientation == MRAIDForceOrientationNone
            preferredOrientation = currentInterfaceOrientation;
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mrak - Gestures

- (void)setTapObserver {
    if(!SK_SUPPRESS_BANNER_AUTO_REDIRECT){
        return;  // return without adding the GestureRecognizer if the feature is not enabled
    }
    // One finger, one tap
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(oneFingerOneTap)];
    
    // Set up
    [self.tapGestureRecognizer setNumberOfTapsRequired:1];
    [self.tapGestureRecognizer setNumberOfTouchesRequired:1];
    [self.tapGestureRecognizer setDelegate:self];
    
    [self.view addGestureRecognizer:self.tapGestureRecognizer];
}

- (void)oneFingerOneTap {
    [self.delegate mraidModalViewControllerDidRecieveTap:self];
}

- (void)removeTapObserver {
    self.tapGestureRecognizer.delegate=nil;
    self.tapGestureRecognizer=nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;   // required to allow UIWebview to work correctly, see  http://stackoverflow.com/questions/2909807/does-uigesturerecognizer-work-on-a-uiwebview
}


#pragma mark - status bar

// This is to hide the status bar on iOS 6 and lower.
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    isStatusBarHidden = [[UIApplication sharedApplication] isStatusBarHidden];
    if (SYSTEM_VERSION_LESS_THAN(@"7.0")) {
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    hasViewAppeared = YES;
    
    if (hasRotated) {
        [self.delegate mraidModalViewControllerDidRotate:self];
        hasRotated = NO;
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (SYSTEM_VERSION_LESS_THAN(@"7.0")){
        [[UIApplication sharedApplication] setStatusBarHidden:isStatusBarHidden withAnimation:UIStatusBarAnimationFade];
    }
}

// This is to hide the status bar on iOS 7.
- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - rotation/orientation

- (BOOL)shouldAutorotate
{
    NSArray *supportedOrientationsInPlist = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
    
    BOOL isPortraitSupported = [supportedOrientationsInPlist containsObject:@"UIInterfaceOrientationPortrait"];
    BOOL isPortraitUpsideDownSupported = [supportedOrientationsInPlist containsObject:@"UIInterfaceOrientationPortraitUpsideDown"];
    BOOL isLandscapeLeftSupported = [supportedOrientationsInPlist containsObject:@"UIInterfaceOrientationLandscapeLeft"];
    BOOL isLandscapeRightSupported = [supportedOrientationsInPlist containsObject:@"UIInterfaceOrientationLandscapeRight"];
    
    UIInterfaceOrientation currentInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];

    BOOL retval = NO;

    if (orientationProperties.forceOrientation == MRAIDForceOrientationPortrait) {
        retval = (isPortraitSupported && isPortraitUpsideDownSupported);
    } else if (orientationProperties.forceOrientation == MRAIDForceOrientationLandscape) {
        retval = (isLandscapeLeftSupported && isLandscapeRightSupported);
    } else {
        // orientationProperties.forceOrientation == MRAIDForceOrientationNone
        if (orientationProperties.allowOrientationChange) {
            retval = YES;
        } else {
            if (UIInterfaceOrientationIsPortrait(currentInterfaceOrientation)) {
                retval = (isPortraitSupported && isPortraitUpsideDownSupported);
            } else {
                // currentInterfaceOrientation is landscape
                return (isLandscapeLeftSupported && isLandscapeRightSupported);
            }
        }
    }
    
    return retval;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return preferredOrientation;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (orientationProperties.forceOrientation == MRAIDForceOrientationPortrait) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    
    if (orientationProperties.forceOrientation == MRAIDForceOrientationLandscape) {
        return UIInterfaceOrientationMaskLandscape;
    }
    
    // orientationProperties.forceOrientation == MRAIDForceOrientationNone
    
    if (!orientationProperties.allowOrientationChange) {
        if (UIInterfaceOrientationIsPortrait(preferredOrientation)) {
            return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
        } else {
            return UIInterfaceOrientationMaskLandscape;
        }
    }
    
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    
    // willRotateToInterfaceOrientation code goes here
   
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // willAnimateRotationToInterfaceOrientation code goes here
        [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
        
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // didRotateFromInterfaceOrientation goes here
        if (hasViewAppeared) {
            [self.delegate mraidModalViewControllerDidRotate:self];
            hasRotated = NO;
        }
    }];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if (hasViewAppeared) {
        [self.delegate mraidModalViewControllerDidRotate:self];
        hasRotated = NO;
    }
}

- (void)forceToOrientation:(SKMRAIDOrientationProperties *)orientationProps;
{
    NSString *orientationString;
    switch (orientationProps.forceOrientation) {
        case MRAIDForceOrientationPortrait:
            orientationString = @"portrait";
            break;
        case MRAIDForceOrientationLandscape:
            orientationString = @"landscape";
            break;
        case MRAIDForceOrientationNone:
            orientationString = @"none";
            break;
        default:
            orientationString = @"wtf!";
            break;
    }


    orientationProperties = orientationProps;
    UIInterfaceOrientation currentInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (orientationProperties.forceOrientation == MRAIDForceOrientationPortrait) {
        if (UIInterfaceOrientationIsPortrait(currentInterfaceOrientation)) {
            // this will accomodate both portrait and portrait upside down
            preferredOrientation = currentInterfaceOrientation;
        } else {
            preferredOrientation = UIInterfaceOrientationPortrait;
        }
    } else if (orientationProperties.forceOrientation == MRAIDForceOrientationLandscape) {
        if (UIInterfaceOrientationIsLandscape(currentInterfaceOrientation)) {
            // this will accomodate both landscape left and landscape right
            preferredOrientation = currentInterfaceOrientation;
        } else {
            preferredOrientation = UIInterfaceOrientationLandscapeLeft;
        }
    } else {
        // orientationProperties.forceOrientation == MRAIDForceOrientationNone
        if (orientationProperties.allowOrientationChange) {
            UIDeviceOrientation currentDeviceOrientation = [[UIDevice currentDevice] orientation];
            // NB: UIInterfaceOrientationLandscapeLeft = UIDeviceOrientationLandscapeRight
            // and UIInterfaceOrientationLandscapeLeft = UIDeviceOrientationLandscapeLeft !
            if (currentDeviceOrientation == UIDeviceOrientationPortrait) {
                preferredOrientation = UIInterfaceOrientationPortrait;
            } else if (currentDeviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
                preferredOrientation = UIInterfaceOrientationPortraitUpsideDown;
            } else if (currentDeviceOrientation == UIDeviceOrientationLandscapeRight) {
                preferredOrientation = UIInterfaceOrientationLandscapeLeft;
            } else if (currentDeviceOrientation == UIDeviceOrientationLandscapeLeft) {
                preferredOrientation = UIInterfaceOrientationLandscapeRight;
            }
            
            // Make sure that the preferredOrientation is supported by the app. If not, then change it.
            
            NSString *preferredOrientationString;
            if (preferredOrientation == UIInterfaceOrientationPortrait) {
                preferredOrientationString = @"UIInterfaceOrientationPortrait";
            } else if (preferredOrientation == UIInterfaceOrientationPortraitUpsideDown) {
                preferredOrientationString = @"UIInterfaceOrientationPortraitUpsideDown";
            } else if (preferredOrientation == UIInterfaceOrientationLandscapeLeft) {
                preferredOrientationString = @"UIInterfaceOrientationLandscapeLeft";
            } else if (preferredOrientation == UIInterfaceOrientationLandscapeRight) {
                preferredOrientationString = @"UIInterfaceOrientationLandscapeRight";
            }
            NSArray *supportedOrientationsInPlist = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
            BOOL isSupported = [supportedOrientationsInPlist containsObject:preferredOrientationString];
            if (!isSupported) {
                // use the first supported orientation in the plist
                preferredOrientationString = supportedOrientationsInPlist[0];
                if ([preferredOrientationString isEqualToString:@"UIInterfaceOrientationPortrait"]) {
                    preferredOrientation = UIInterfaceOrientationPortrait;
                } else if ([preferredOrientationString isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"]) {
                    preferredOrientation = UIInterfaceOrientationPortraitUpsideDown;
                } else if ([preferredOrientationString isEqualToString:@"UIInterfaceOrientationLandscapeLeft"]) {
                    preferredOrientation = UIInterfaceOrientationLandscapeLeft;
                } else if ([preferredOrientationString isEqualToString:@"UIInterfaceOrientationLandscapeRight"]) {
                    preferredOrientation = UIInterfaceOrientationLandscapeRight;
                }
            }
        } else {
            // orientationProperties.allowOrientationChange == NO
            preferredOrientation = currentInterfaceOrientation;
        }
    }
    
    
    if ((orientationProperties.forceOrientation == MRAIDForceOrientationPortrait && UIInterfaceOrientationIsPortrait(currentInterfaceOrientation)) ||
        (orientationProperties.forceOrientation == MRAIDForceOrientationLandscape && UIInterfaceOrientationIsLandscape(currentInterfaceOrientation)) ||
        (orientationProperties.forceOrientation == MRAIDForceOrientationNone && (preferredOrientation == currentInterfaceOrientation)))
    {
        return;
    }
    
    UIViewController *presentingVC;
    if ([self respondsToSelector:@selector(presentingViewController)]) {
        // iOS 5+
        presentingVC = self.presentingViewController;
    } else {
        // iOS 4
        presentingVC = self.parentViewController;
    }
    
    if ([self respondsToSelector:@selector(presentViewController:animated:completion:)] &&
        [self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        // iOS 6+
        [self dismissViewControllerAnimated:NO completion:^{
             [presentingVC presentViewController:self animated:NO completion:nil];
         }];
    } else {
        // < iOS 6
        // Turn off the warning about using a deprecated method.
        [self dismissViewControllerAnimated:YES completion:^{
            [presentingVC presentViewController:self animated:YES completion:nil];
        }];
    }
    
    hasRotated = YES;
}

- (NSString *)stringfromUIInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            return @"portrait";
        case UIInterfaceOrientationPortraitUpsideDown:
            return @"portrait upside down";
        case UIInterfaceOrientationLandscapeLeft:
            return @"landscape left";
        case UIInterfaceOrientationLandscapeRight:
            return @"landscape right";
        default:
            return @"unknown";
    }
}

@end
