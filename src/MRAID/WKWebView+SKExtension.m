//
//  WKWebView+SKExtension.m
//
//  Copyright © 2017 Nexage. All rights reserved.
//

#import "WKWebView+SKExtension.h"

@implementation WKWebView (SKExtension)

- (void)skEvaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf evaluateJavaScript:javaScriptString completionHandler:completionHandler];
    });
}

@end
