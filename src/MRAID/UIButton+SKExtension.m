//
//  UIButton+SKExtension.m
//  MRAID
//
//  Created by Stas Kochkin on 21/09/16.
//  Copyright © 2016 Nexage. All rights reserved.
//

#import "UIButton+SKExtension.h"
#import <objc/runtime.h>

static const NSString *kSKHitTestEdgeInsetsKey = @"SKHitTestEdgeInsetsKey";

@implementation UIButton (SKExtension)

//@dynamic sk_hitTestEdgeInsets;

- (void)setSk_hitTestEdgeInsets:(UIEdgeInsets)sk_hitTestEdgeInsets {
    NSValue *value = [NSValue value:&sk_hitTestEdgeInsets withObjCType:@encode(UIEdgeInsets)];
    objc_setAssociatedObject(self, &kSKHitTestEdgeInsetsKey, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)sk_hitTestEdgeInsets {
    NSValue *value = objc_getAssociatedObject(self, &kSKHitTestEdgeInsetsKey);
    if (value) {
        UIEdgeInsets edgeInsets; [value getValue:&edgeInsets];
        return edgeInsets;
    } else {
        return UIEdgeInsetsZero;
    }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if(UIEdgeInsetsEqualToEdgeInsets(self.sk_hitTestEdgeInsets, UIEdgeInsetsZero) || !self.enabled || self.hidden) {
        return [super pointInside:point withEvent:event];
    }
    
    CGRect relativeFrame = self.bounds;
    CGRect hitFrame = UIEdgeInsetsInsetRect(relativeFrame, self.sk_hitTestEdgeInsets);
    
    return CGRectContainsPoint(hitFrame, point);
}


@end
