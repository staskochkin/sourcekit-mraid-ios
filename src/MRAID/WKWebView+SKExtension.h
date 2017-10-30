//
//  WKWebView+SKExtension.h
//
//  Copyright © 2017 Nexage. All rights reserved.
//

#import <WebKit/WebKit.h>

@interface WKWebView (SKExtension)

- (void)skEvaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler;

@end
