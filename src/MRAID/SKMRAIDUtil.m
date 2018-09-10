//
//  SKMRAIDUtil.m
//  MRAID
//
//  Created by Jay Tucker on 11/8/13.
//  Copyright (c) 2013 Nexage. All rights reserved.
//

#import "SKMRAIDUtil.h"

@implementation SKMRAIDUtil

+ (NSString *)processRawHtml:(NSString *)rawHtml
{
    NSString *processedHtml = rawHtml;
    NSRange range;
    
    // Remove the mraid.js script tag.
    // We expect the tag to look like this:
    // <script src='mraid.js'></script>
    // But we should also be to handle additional attributes and whitespace like this:
    // <script  type = 'text/javascript'  src = 'mraid.js' > </script>
    
    NSString *pattern = @"<script\\s+[^>]*\\bsrc\\s*=\\s*([\\\"\\\'])mraid\\.js\\1[^>]*>\\s*</script>\\n*";
    NSError *error = NULL;
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    processedHtml = [regex stringByReplacingMatchesInString:processedHtml
                                                    options:0
                                                      range:NSMakeRange(0, [processedHtml length])
                                               withTemplate:@""];
    
    // Add html, head, and/or body tags as needed.
    BOOL hasHtmlTag = ([rawHtml rangeOfString:@"<html"].location != NSNotFound) || ([rawHtml rangeOfString:@"<!DOCTYPE html"].location != NSNotFound);
    range = [rawHtml rangeOfString:@"<head"];
    BOOL hasHeadTag = (range.location != NSNotFound);
    range = [rawHtml rangeOfString:@"<body"];
    BOOL hasBodyTag = (range.location != NSNotFound);
    
    // basic sanity checks
    if ((!hasHtmlTag && (hasHeadTag || hasBodyTag)) ||
        (hasHtmlTag && !hasBodyTag)) {
        return rawHtml;
    }
    
    if (!hasHtmlTag) {
        processedHtml = [NSString stringWithFormat:
                         @"<html>\n"
                         "<head>\n"
                         "</head>\n"
                         "<body>\n"
                         "<div align='center'>\n"
                         "%@"
                         "</div>\n"
                         "</body>\n"
                         "</html>",
                         processedHtml
                         ];
    } else if (!hasHeadTag) {
        // html tag exists, head tag doesn't, so add it
        pattern = @"<html[^>]*>";
        error = NULL;
        regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
        processedHtml = [regex stringByReplacingMatchesInString:processedHtml
                                                        options:0
                                                          range:NSMakeRange(0, [processedHtml length])
                                                   withTemplate:@"$0\n<head>\n</head>"];
    }
    
    // Add meta and style tags to head tag.
    NSString *metaTag =
    @"<meta name='viewport' content='width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no', shrink-to-fit=YES />";
    
    NSString *styleTag =
    @"<style>\n"
    "body { margin:0; padding:0; }\n"
    "*:not(input) { -webkit-touch-callout:none; -webkit-user-select:none; -webkit-text-size-adjust:none; }\n"
    "</style>";
    
    pattern = @"<head[^>]*>";
    error = NULL;
    regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                      options:NSRegularExpressionCaseInsensitive
                                                        error:&error];
    processedHtml = [regex stringByReplacingMatchesInString:processedHtml
                                                    options:0
                                                      range:NSMakeRange(0, [processedHtml length])
                                               withTemplate:[NSString stringWithFormat:@"$0\n%@\n%@", metaTag, styleTag]];
    
    return processedHtml;
}

@end
