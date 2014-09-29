//
//  SKMRAIDParser.m
//  MRAID
//
//  Created by Jay Tucker on 9/13/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import "SKMRAIDParser.h"

#import "SKLogger.h"

@interface SKMRAIDParser ()

- (BOOL)isValidCommand:(NSString *)command;
- (BOOL)checkParamsForCommand:(NSString *)command params:(NSDictionary *)params;

@end

@implementation SKMRAIDParser

- (NSDictionary *)parseCommandUrl:(NSString *)commandUrl;
{
    /*
     The command is a URL string that looks like this:
     
     mraid://command?param1=val1&param2=val2&...
     
     We need to parse out the command, create a dictionary of the paramters and their associated values,
     and then send an appropriate message back to the MRAIDView to run the command.
     */
    
    [SKLogger debug:@"MRAID - Parser" withMessage:[NSString stringWithFormat:@"%@ %@", NSStringFromSelector(_cmd), commandUrl]];
    
    // Remove mraid:// prefix.
    NSString *s = [commandUrl substringFromIndex:8];
    
    NSString *command;
    NSMutableDictionary *params;
    
    // Check for parameters, parse them if found
    NSRange range = [s rangeOfString:@"?"];
    if (range.location != NSNotFound) {
        command = [s substringToIndex:range.location];
        NSString *paramStr = [s substringFromIndex:(range.location + 1)];
        NSArray *paramArray = [paramStr componentsSeparatedByString:@"&"];
        params = [NSMutableDictionary dictionaryWithCapacity:5];
        for (NSString *param in paramArray) {
            range = [param rangeOfString:@"="];
            NSString *key = [param substringToIndex:range.location];
            NSString *val = [param substringFromIndex:(range.location + 1)];
            [params setValue:val forKey:key];
        }
    } else {
        command = s;
    }
    
    // Check for valid command.
    if (![self isValidCommand:command]) {
        [SKLogger warning:@"MRAID - Parser" withMessage:[NSString stringWithFormat:@"command %@ is unknown", command]];
        return nil;
    }
    
    // Check for valid parameters for the given command.
    if (![self checkParamsForCommand:command params:params]) {
        [SKLogger warning:@"MRAID - Parser" withMessage:[NSString stringWithFormat:@"command URL %@ is missing parameters", commandUrl]];
        return nil;
    }
    
    NSObject *paramObj;
    if (
        [command isEqualToString:@"createCalendarEvent"] ||
        [command isEqualToString:@"expand"] ||
        [command isEqualToString:@"open"] ||
        [command isEqualToString:@"playVideo"] ||
        [command isEqualToString:@"setOrientationProperties"] ||
        [command isEqualToString:@"setResizeProperties"] ||
        [command isEqualToString:@"storePicture"] ||
        [command isEqualToString:@"useCustomClose"]
        ) {
        if ([command isEqualToString:@"createCalendarEvent"]) {
            paramObj = [params valueForKey:@"eventJSON"];
        } else if ([command isEqualToString:@"expand"] ||
                   [command isEqualToString:@"open"] ||
                   [command isEqualToString:@"playVideo"] ||
                   [command isEqualToString:@"storePicture"]) {
            paramObj = [params valueForKey:@"url"];
        } else if ([command isEqualToString:@"setOrientationProperties"] ||
                   [command isEqualToString:@"setResizeProperties"]) {
            paramObj = params;
        } else if ([command isEqualToString:@"useCustomClose"]) {
            paramObj = [params valueForKey:@"useCustomClose"];
        }
        command = [command stringByAppendingString:@":"];
    }

    NSMutableDictionary *commandDict = [@{@"command" : command} mutableCopy];
    if (paramObj) {
        commandDict[@"paramObj"] = paramObj;
    }
    return commandDict;
}

- (BOOL)isValidCommand:(NSString *)command
{
    NSArray *kCommands = @[
                           @"createCalendarEvent",
                           @"close",
                           @"expand",
                           @"open",
                           @"playVideo",
                           @"resize",
                           @"setOrientationProperties",
                           @"setResizeProperties",
                           @"storePicture",
                           @"useCustomClose"
                           ];

    return [kCommands containsObject:command];
}

- (BOOL)checkParamsForCommand:(NSString *)command params:(NSDictionary *)params;
{
    if ([command isEqualToString:@"createCalendarEvent"]) {
        return ([params valueForKey:@"eventJSON"] != nil);
    } else if ([command isEqualToString:@"open"] || [command isEqualToString:@"playVideo"] || [command isEqualToString:@"storePicture"]) {
        return ([params valueForKey:@"url"] != nil);
    } else if ([command isEqualToString:@"setOrientationProperties"]) {
        return (
                [params valueForKey:@"allowOrientationChange"] != nil &&
                [params valueForKey:@"forceOrientation"] != nil
                );
    } else if ([command isEqualToString:@"setResizeProperties"]) {
        return (
                [params valueForKey:@"width"] != nil &&
                [params valueForKey:@"height"] != nil &&
                [params valueForKey:@"offsetX"] != nil &&
                [params valueForKey:@"offsetY"] != nil &&
                [params valueForKey:@"customClosePosition"] != nil &&
                [params valueForKey:@"allowOffscreen"] != nil
                );
    } else if ([command isEqualToString:@"useCustomClose"]) {
        return ([params valueForKey:@"useCustomClose"] != nil);
    }
    return YES;
}

@end
