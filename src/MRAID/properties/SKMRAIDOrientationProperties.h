//
//  SKMRAIDOrientationProperties.h
//  MRAID
//
//  Created by Jay Tucker on 9/16/13.
//  Copyright (c) 2013 Nexage, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    MRAIDForceOrientationPortrait,
    MRAIDForceOrientationLandscape,
    MRAIDForceOrientationNone
} SKMRAIDForceOrientation;

@interface SKMRAIDOrientationProperties : NSObject

@property (nonatomic, assign) BOOL allowOrientationChange;
@property (nonatomic, assign) SKMRAIDForceOrientation forceOrientation;

+ (SKMRAIDForceOrientation)MRAIDForceOrientationFromString:(NSString *)s;

@end
