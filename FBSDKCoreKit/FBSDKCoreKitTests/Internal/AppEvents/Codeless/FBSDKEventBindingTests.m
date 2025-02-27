// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <XCTest/XCTest.h>

#import "FBSDKCodelessParameterComponent.h"
#import "FBSDKCoreKitTests-Swift.h"
#import "FBSDKEventBinding.h"
#import "FBSDKEventBindingManager.h"

@interface FBSDKEventBindingTests : XCTestCase
{
  UIWindow *window;
  FBSDKEventBindingManager *eventBindingManager;
  UIButton *btnBuy;
  UIButton *btnConfirm;
  UIStepper *stepper;
}

@end

@interface FBSDKEventBinding (Testing)

+ (NSString *)findParameterOfPath:(NSArray *)path
                         pathType:(NSString *)pathType
                       sourceView:(UIView *)sourceView;

@end

@implementation FBSDKEventBindingTests

- (void)setUp
{
  [super setUp];

  eventBindingManager = [[FBSDKEventBindingManager alloc]
                         initWithJSON:[SampleRawRemoteEventBindings sampleDictionary]];
  window = [UIWindow new];
  UIViewController *vc = [UIViewController new];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];

  UITabBarController *tab = [UITabBarController new];
  tab.viewControllers = @[nav];
  window.rootViewController = tab;

  UIStackView *firstStackView = [UIStackView new];
  [vc.view addSubview:firstStackView];
  UIStackView *secondStackView = [UIStackView new];
  [firstStackView addSubview:secondStackView];

  btnBuy = [UIButton buttonWithType:UIButtonTypeCustom];
  [btnBuy setTitle:NSLocalizedString(@"Buy", nil) forState:UIControlStateNormal];
  [firstStackView addSubview:btnBuy];

  UILabel *lblPrice = [UILabel new];
  lblPrice.text = NSLocalizedString(@"$2.0", nil);
  [firstStackView addSubview:lblPrice];

  btnConfirm = [UIButton buttonWithType:UIButtonTypeCustom];
  [btnConfirm setTitle:NSLocalizedString(@"Confirm", nil) forState:UIControlStateNormal];
  [firstStackView addSubview:btnConfirm];

  lblPrice = [UILabel new];
  lblPrice.text = NSLocalizedString(@"$3.0", nil);
  [secondStackView addSubview:lblPrice];

  stepper = [UIStepper new];
  [secondStackView addSubview:stepper];
}

- (void)testDefaultNumberParser
{
  XCTAssertTrue(
    [(NSObject *)FBSDKEventBinding.numberParser isMemberOfClass:FBSDKAppEventsNumberParser.class],
    "The default number parser for an event binding should be an instance of FBSDKAppEventsNumberParser"
  );
}

- (void)testMatching
{
  NSArray *bindings = [FBSDKEventBindingManager parseArray:[SampleRawRemoteEventBindings sampleDictionary][@"event_bindings"]];
  FBSDKEventBinding *binding = bindings[0];
  XCTAssertTrue([FBSDKEventBinding isViewMatchPath:stepper path:binding.path]);

  binding = bindings[1];
  FBSDKCodelessParameterComponent *component = binding.parameters[0];
  XCTAssertTrue([FBSDKEventBinding isViewMatchPath:btnBuy path:binding.path]);
  NSString *price = [FBSDKEventBinding findParameterOfPath:component.path pathType:component.pathType sourceView:btnBuy];
  XCTAssertEqual(price, @"$2.0");

  binding = bindings[2];
  component = binding.parameters[0];
  XCTAssertTrue([FBSDKEventBinding isViewMatchPath:btnConfirm path:binding.path]);
  price = [FBSDKEventBinding findParameterOfPath:component.path pathType:component.pathType sourceView:btnConfirm];
  XCTAssertEqual(price, @"$3.0");
  component = binding.parameters[1];
  NSString *action = [FBSDKEventBinding findParameterOfPath:component.path pathType:component.pathType sourceView:btnConfirm];
  XCTAssertEqual(action, @"Confirm");
}

- (void)testEventBindingEquation
{
  NSArray *bindings = [FBSDKEventBindingManager parseArray:[SampleRawRemoteEventBindings sampleDictionary][@"event_bindings"]];
  XCTAssertTrue([bindings[0] isEqualToBinding:bindings[0]]);
  XCTAssertFalse([bindings[0] isEqualToBinding:bindings[1]]);
}

- (void)testParsing
{
  for (int i = 0; i < 100; i++) {
    NSDictionary *sampleData = [SampleRawRemoteEventBindings sampleDictionary];
    [FBSDKEventBindingManager parseArray:@[[Fuzzer randomizeWithJson:sampleData]]];
  }
}

@end
