//
//  NSURL+SecuredURL.m
//  MRAID
//
//  Created by Lozhkin Ilya on 11/7/16.
//  Copyright © 2016 Nexage. All rights reserved.
//

#import "NSURL+SecuredURL.h"

@implementation NSURL (SecuredURL)

- (NSURL *)parseUrlToSecuredUrl {
    NSString * absoluteUrl = [self absoluteString];
    NSURL * newUrl = self;
    
    if (!self || [absoluteUrl isEqualToString:@""]) {
        return nil;
    }
    
    if ([absoluteUrl hasPrefix:@"http://"]) {
        newUrl = [NSURL URLWithString:[absoluteUrl stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"]];
    } else if (![absoluteUrl hasPrefix:@"https://"]) {
        newUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@",absoluteUrl]];
    }
    
    return newUrl;
}

@end
