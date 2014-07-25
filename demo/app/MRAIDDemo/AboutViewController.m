//
//  AboutViewController.m
//  MRAIDDemo
//
//  Created by Muthu on 11/4/13.
//  Copyright (c) 2013 Nexage. All rights reserved.
//

#import "AboutViewController.h"
#import "MRAIDSettings.h"

@implementation AboutViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    // Fill version string
    [self.versionLabel setText:[NSString stringWithFormat:@"MRAID SourceKit v%@ & Demo v%@", kMRAIDKitVersion, [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
