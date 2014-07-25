//
//  MRAID_Tests.m
//  MRAID Tests
//
//  Created by Muthu on 11/13/13.
//  Copyright (c) 2013 Nexage. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SKMRAIDParser.h"
#import "SKMRAIDUtil.h"

@interface MRAID_Tests : XCTestCase

@end

@implementation MRAID_Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMRAIDParserParsingPositive
{
    SKMRAIDParser *parser = [[SKMRAIDParser alloc] init];
    NSDictionary* dict;
    
    // Test 1
    dict = [parser parseCommandUrl:@"mraid://createCalendarEvent?eventJSON={start:'2011-03-24T09:00-08:00'}"];
    XCTAssertTrue([dict[@"command"] isEqualToString:@"createCalendarEvent:"], @"createCalendarEvent function parsing failed");
    
    // Test 2
    dict = [parser parseCommandUrl:@"mraid://expand"];
    XCTAssertTrue([dict[@"command"] isEqualToString:@"expand:"], @"Expand 1-part function parsing failed");
    
    // Test 3
    dict = [parser parseCommandUrl:@"mraid://expand?url=http://newpage.com/mraid.html"];
    XCTAssertTrue([dict[@"command"] isEqualToString:@"expand:"], @"Expand 2-part function parsing failed");
    
    // Test 4
    dict = [parser parseCommandUrl:@"mraid://open?url=http://nexage.com"];
    XCTAssertTrue([dict[@"command"] isEqualToString:@"open:"], @"Open function parsing failed");
    
    // Test 5
    dict = [parser parseCommandUrl:@"mraid://playVideo?url=http://nexage.com"];
    XCTAssertTrue([dict[@"command"] isEqualToString:@"playVideo:"], @"playVideo function parsing failed");
    
    // Test 6
    dict = [parser parseCommandUrl:@"mraid://setOrientationProperties?allowOrientationChange=true&forceOrientation=none"];
    XCTAssertTrue([dict[@"command"] isEqualToString:@"setOrientationProperties:"], @"setOrientationProperties function parsing failed");
    
    // Test 7
    dict = [parser parseCommandUrl:@"mraid://setResizeProperties?width=320&height=450&customClosePosition=top-right&offsetX=0&offsetY=0&allowOffscreen=true"];
    XCTAssertTrue([dict[@"command"] isEqualToString:@"setResizeProperties:"], @"setResizeProperties function parsing failed");
    
    // Test 8
    dict = [parser parseCommandUrl:@"mraid://useCustomClose?useCustomClose=true"];
    XCTAssertTrue([dict[@"command"] isEqualToString:@"useCustomClose:"], @"useCustomClose function parsing failed");
}


- (void)testMRAIDParserParsingNegative
{
    SKMRAIDParser *parser = [[SKMRAIDParser alloc] init];
    NSDictionary* dict;
    
    // Test 1 - calendar, bad JSON
    // Test 2 - expand 2 part- empty url
    dict = [parser parseCommandUrl:@"mraid://expand?url="];
    XCTAssertNotNil(dict, @"expand function parsing empty url failed");
    
    // Test 3 - open - empty url
    dict = [parser parseCommandUrl:@"mraid://open?url="];
    XCTAssertNotNil(dict, @"Open function parsing empty url failed");
    
    // Test 4 - playVideo - empty url
    dict = [parser parseCommandUrl:@"mraid://playVideo?url="];
    XCTAssertNotNil(dict, @"playVideo function parsing empty url failed");
    
    // Test 5 - setOrientationProperties - no parameters
    dict = [parser parseCommandUrl:@"mraid://setOrientationProperties"];
    XCTAssertNil(dict, @"setOrientationProperties function parsing no params failed");
    
    // Test 6 - setResizeProperties - no parameters
    dict = [parser parseCommandUrl:@"mraid://setResizeProperties"];
    XCTAssertNil(dict, @"setResizeProperties function parsing no params failed");
    
    // Test 7 - useCustomClose - no param
    dict = [parser parseCommandUrl:@"mraid://useCustomClose"];
    XCTAssertNil(dict, @"useCustomClose function parsing no param failed");
}

- (void)testMRAIDUtilProcessRawHTML
{    
    XCTAssertEqualObjects([[SKMRAIDUtil processRawHtml:@"test"] stringByReplacingOccurrencesOfString:@"\n" withString:@""], @"<html><head><meta name='viewport' content='width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no' /><style>body { margin:0; padding:0; }*:not(input) { -webkit-touch-callout:none; -webkit-user-select:none; -webkit-text-size-adjust:none; }</style></head><body><div align='center'>test</div></body></html>", @"Error parsing html");
    
    XCTAssertNil([SKMRAIDUtil processRawHtml:@"<body>test</body>"], @"Error parsing html");
    
    XCTAssertEqualObjects([[SKMRAIDUtil processRawHtml:@"<iframe src='http://test.com'>test</iframe>"] stringByReplacingOccurrencesOfString:@"\n" withString:@""], @"<html><head><meta name='viewport' content='width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no' /><style>body { margin:0; padding:0; }*:not(input) { -webkit-touch-callout:none; -webkit-user-select:none; -webkit-text-size-adjust:none; }</style></head><body><div align='center'><iframe src='http://test.com'>test</iframe></div></body></html>", @"Error parsing html");
    
    XCTAssertEqualObjects([[SKMRAIDUtil processRawHtml:@"<html><head><script src='mraid.js'/></head><body>test</body></html>"] stringByReplacingOccurrencesOfString:@"\n" withString:@""], @"<html><head><meta name='viewport' content='width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no' /><style>body { margin:0; padding:0; }*:not(input) { -webkit-touch-callout:none; -webkit-user-select:none; -webkit-text-size-adjust:none; }</style><script src='mraid.js'/></head><body>test</body></html>", @"Error parsing html");
}

@end
