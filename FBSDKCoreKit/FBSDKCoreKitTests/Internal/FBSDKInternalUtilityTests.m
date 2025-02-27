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

#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "FBSDKCoreKit.h"
#import "FBSDKCoreKitTests-Swift.h"
#import "FBSDKInternalUtility.h"
#import "FBSDKTestCase.h"

@interface FBSDKInternalUtility (Testing)

+ (BOOL)_canOpenURLScheme:(NSString *)scheme;
+ (void)resetQuerySchemesCache;
+ (void)resetDidCheckRegisteredCanOpenUrlSchemes;
+ (void)resetIsFacebookAppInstalledCache;
+ (void)resetDidCheckIfMessengerAppInstalledCache;
+ (void)resetDidCheckIfMSQRDAppInstalledCache;
+ (void)resetDidCheckOperatingSystemVersion;
+ (void)resetFetchingUrlSchemes;

@end

@interface FBSDKAuthenticationToken (Testing)

- (instancetype)initWithTokenString:(NSString *)tokenString
                              nonce:(NSString *)nonce
                        graphDomain:(NSString *)graphDomain;

@end

@interface FBSDKInternalUtilityTests : FBSDKTestCase
@end

@implementation FBSDKInternalUtilityTests
{
  id _notificationCenterSpy;
}

- (void)setUp
{
  [super setUp];

  [FBSDKSettings reset];

  [FBSDKInternalUtility reset];
  [FBSDKInternalUtility deleteFacebookCookies];
}

- (void)tearDown
{
  [FBSDKSettings reset];

  [super tearDown];
}

// MARK: - Facebook URL

- (void)testFacebookURL
{
  FBSDKSettings.facebookDomainPart = @"";
  NSString *URLString;
  NSString *tier = [FBSDKSettings facebookDomainPart];

  URLString = [FBSDKInternalUtility
               facebookURLWithHostPrefix:@""
               path:@""
               queryParameters:@{}
               error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://facebook.com/" FBSDK_TARGET_PLATFORM_VERSION);

  URLString = [FBSDKInternalUtility
               facebookURLWithHostPrefix:@"m."
               path:@""
               queryParameters:@{}
               error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/" FBSDK_TARGET_PLATFORM_VERSION);

  URLString = [FBSDKInternalUtility
               facebookURLWithHostPrefix:@"m"
               path:@""
               queryParameters:@{}
               error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/" FBSDK_TARGET_PLATFORM_VERSION);

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/dialog/share"
                                              queryParameters:@{}
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/" FBSDK_TARGET_PLATFORM_VERSION @"/dialog/share");

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"dialog/share"
                                              queryParameters:@{}
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/" FBSDK_TARGET_PLATFORM_VERSION @"/dialog/share");

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"dialog/share"
                                              queryParameters:@{ @"key" : @"value" }
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(
    URLString,
    @"https://m.facebook.com/" FBSDK_TARGET_PLATFORM_VERSION @"/dialog/share?key=value"
  );

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/v1.0/dialog/share"
                                              queryParameters:@{}
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/v1.0/dialog/share");

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/dialog/share"
                                              queryParameters:@{}
                                               defaultVersion:@"v2.0"
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/v2.0/dialog/share");

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/v1.0/dialog/share"
                                              queryParameters:@{}
                                               defaultVersion:@"v2.0"
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/v1.0/dialog/share");

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/v987654321.2/dialog/share"
                                              queryParameters:@{}
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/v987654321.2/dialog/share");

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/v.1/dialog/share"
                                              queryParameters:@{}
                                               defaultVersion:@"v2.0"
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/v2.0/v.1/dialog/share");

  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/v1/dialog/share"
                                              queryParameters:@{}
                                               defaultVersion:@"v2.0"
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/v2.0/v1/dialog/share");
  [FBSDKSettings setFacebookDomainPart:tier];

  FBSDKSettings.graphAPIVersion = @"v3.3";
  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/v1/dialog/share"
                                              queryParameters:@{}
                                               defaultVersion:@""
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/v3.3/v1/dialog/share");
  FBSDKSettings.graphAPIVersion = nil;
  URLString = [FBSDKInternalUtility facebookURLWithHostPrefix:@"m"
                                                         path:@"/dialog/share"
                                              queryParameters:@{}
                                               defaultVersion:@""
                                                        error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://m.facebook.com/" FBSDK_TARGET_PLATFORM_VERSION @"/dialog/share");
}

- (void)testFacebookGamingURL
{
  FBSDKSettings.facebookDomainPart = @"";
  FBSDKAuthenticationToken *authToken = [[FBSDKAuthenticationToken alloc] initWithTokenString:@"token_string"
                                                                                        nonce:@"nonce"
                                                                                  graphDomain:@"gaming"];
  [FBSDKAuthenticationToken setCurrentAuthenticationToken:authToken];
  NSString *URLString;

  URLString = [FBSDKInternalUtility
               facebookURLWithHostPrefix:@"graph"
               path:@""
               queryParameters:@{}
               error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://graph.fb.gg/" FBSDK_TARGET_PLATFORM_VERSION);

  URLString = [FBSDKInternalUtility
               facebookURLWithHostPrefix:@"graph-video"
               path:@""
               queryParameters:@{}
               error:NULL].absoluteString;
  XCTAssertEqualObjects(URLString, @"https://graph-video.fb.gg/" FBSDK_TARGET_PLATFORM_VERSION);
}

// MARK: - Extracting Permissions

- (void)testParsingPermissionsWithFuzzyValues
{
  NSMutableSet *grantedPermissions = [NSMutableSet set];
  NSMutableSet *declinedPermissions = [NSMutableSet set];
  NSMutableSet *expiredPermissions = [NSMutableSet set];

  // A lack of a runtime crash is considered a success here.
  for (int i = 0; i < 100; i++) {
    [FBSDKInternalUtility extractPermissionsFromResponse:SampleRawRemotePermissionList.randomValues
                                      grantedPermissions:grantedPermissions
                                     declinedPermissions:declinedPermissions
                                      expiredPermissions:expiredPermissions];
  }
}

- (void)testExtractingPermissionsFromResponseWithInvalidTopLevelKey
{
  NSMutableSet *grantedPermissions = [NSMutableSet set];
  NSMutableSet *declinedPermissions = [NSMutableSet set];
  NSMutableSet *expiredPermissions = [NSMutableSet set];

  [FBSDKInternalUtility extractPermissionsFromResponse:SampleRawRemotePermissionList.missingTopLevelKey
                                    grantedPermissions:grantedPermissions
                                   declinedPermissions:declinedPermissions
                                    expiredPermissions:expiredPermissions];
  XCTAssertEqual(grantedPermissions.count, 0, "Should not add granted permissions if top level key is missing");
  XCTAssertEqual(declinedPermissions.count, 0, "Should not add declined permissions if top level key is missing");
  XCTAssertEqual(expiredPermissions.count, 0, "Should not add expired permissions if top level key is missing");
}

- (void)testExtractingPermissionsFromResponseWithMissingPermissions
{
  NSMutableSet *grantedPermissions = [NSMutableSet set];
  NSMutableSet *declinedPermissions = [NSMutableSet set];
  NSMutableSet *expiredPermissions = [NSMutableSet set];

  [FBSDKInternalUtility extractPermissionsFromResponse:SampleRawRemotePermissionList.missingPermissions
                                    grantedPermissions:grantedPermissions
                                   declinedPermissions:declinedPermissions
                                    expiredPermissions:expiredPermissions];
  XCTAssertEqual(grantedPermissions.count, 0, "Should not add missing granted permissions");
  XCTAssertEqual(declinedPermissions.count, 0, "Should not add missing declined permissions");
  XCTAssertEqual(expiredPermissions.count, 0, "Should not add missing expired permissions");
}

- (void)testExtractingPermissionsFromResponseWithMissingStatus
{
  NSMutableSet *grantedPermissions = [NSMutableSet set];
  NSMutableSet *declinedPermissions = [NSMutableSet set];
  NSMutableSet *expiredPermissions = [NSMutableSet set];

  [FBSDKInternalUtility extractPermissionsFromResponse:SampleRawRemotePermissionList.missingStatus
                                    grantedPermissions:grantedPermissions
                                   declinedPermissions:declinedPermissions
                                    expiredPermissions:expiredPermissions];
  XCTAssertEqual(grantedPermissions.count, 0, "Should not add a permission with a missing status");
  XCTAssertEqual(declinedPermissions.count, 0, "Should not add a permission with a missing status");
  XCTAssertEqual(expiredPermissions.count, 0, "Should not add a permission with a missing status");
}

- (void)testExtractingPermissionsFromResponseWithValidPermissions
{
  NSMutableSet *grantedPermissions = [NSMutableSet set];
  NSMutableSet *declinedPermissions = [NSMutableSet set];
  NSMutableSet *expiredPermissions = [NSMutableSet set];

  [FBSDKInternalUtility extractPermissionsFromResponse:SampleRawRemotePermissionList.validAllStatuses
                                    grantedPermissions:grantedPermissions
                                   declinedPermissions:declinedPermissions
                                    expiredPermissions:expiredPermissions];
  XCTAssertEqual(grantedPermissions.count, 1, "Should add granted permissions when available");
  XCTAssertTrue([grantedPermissions containsObject:@"email"], "Should add the correct permission to granted permissions");

  XCTAssertEqual(declinedPermissions.count, 1, "Should add declined permissions when available");
  XCTAssertTrue([declinedPermissions containsObject:@"birthday"], "Should add the correct permission to declined permissions");

  XCTAssertEqual(expiredPermissions.count, 1, "Should add expired permissions when available");
  XCTAssertTrue([expiredPermissions containsObject:@"first_name"], "Should add the correct permission to expired permissions");
}

// MARK: - Can open URL scheme

- (void)testCanOpenUrlSchemeWithMissingScheme
{
  // Should not even bother checking a nil scheme
  OCMReject([self.sharedApplicationMock canOpenURL:OCMArg.any]);

  XCTAssertFalse(
    [FBSDKInternalUtility _canOpenURLScheme:nil],
    "Should not be able to open a missing scheme"
  );
}

- (void)testCanOpenUrlSchemeWithInvalidSchemes
{
  // Should not even bother checking invalid schemes
  OCMReject([self.sharedApplicationMock canOpenURL:OCMArg.any]);

  NSArray *invalidSchemes = @[
    @"http:",
    @"",
    @"   ",
    @"#@%(*&#$(^#@!$",
    @"////foo",
    @"foo:",
    @"foo:/"
  ];

  for (NSString *scheme in invalidSchemes) {
    [FBSDKInternalUtility _canOpenURLScheme:scheme];
  }
}

- (void)testCanOpenUrlSchemeWithValidSchemes
{
  NSArray *validSchemes = @[
    @"foo",
    @"FOO",
    @"foo+bar",
    @"foo-bar",
    @"foo.bar"
  ];

  for (NSString *scheme in validSchemes) {
    [FBSDKInternalUtility _canOpenURLScheme:scheme];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@:/", scheme]];
    OCMVerify([self.sharedApplicationMock canOpenURL:url]);
  }
}

// MARK: - App URL Scheme

- (void)testAppURLSchemeWithMissingAppIdMissingSuffix
{
  [self stubAppID:nil];
  FBSDKSettings.appURLSchemeSuffix = nil;
  // This is not desired behavior but accurately reflects what is currently written.
  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    @"fb",
    "Should return an app url scheme derived from the app id and app url scheme suffix"
  );
}

- (void)testAppURLSchemeWithMissingAppIdInvalidSuffix
{
  [self stubAppID:nil];
  FBSDKSettings.appURLSchemeSuffix = @"   ";
  // This is not desired behavior but accurately reflects what is currently written.
  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    @"fb   ",
    "Should return an app url scheme derived from the app id and app url scheme suffix"
  );
}

- (void)testAppURLSchemeWithMissingAppIdValidSuffix
{
  [self stubAppID:nil];
  FBSDKSettings.appURLSchemeSuffix = @"foo";
  // This is not desired behavior but accurately reflects what is currently written.
  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    @"fbfoo",
    "Should return an app url scheme derived from the app id and app url scheme suffix"
  );
}

- (void)testAppURLSchemeWithInvalidAppIdMissingSuffix
{
  [self stubAppID:@" "];
  FBSDKSettings.appURLSchemeSuffix = nil;
  NSString *expected = [NSString stringWithFormat:@"fb%@", FBSDKSettings.appID];

  // This is not desired behavior but accurately reflects what is currently written.
  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    expected,
    "Should return an app url scheme derived app id and app url scheme suffix defined in settings"
  );
}

- (void)testAppURLSchemeWithInvalidAppIdInvalidSuffix
{
  [self stubAppID:@" "];
  FBSDKSettings.appURLSchemeSuffix = @" ";
  NSString *expected = [NSString stringWithFormat:@"fb%@%@", FBSDKSettings.appID, FBSDKSettings.appURLSchemeSuffix];

  // This is not desired behavior but accurately reflects what is currently written.
  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    expected,
    "Should return an app url scheme derived app id and app url scheme suffix defined in settings"
  );
}

- (void)testAppURLSchemeWithInvalidAppIdValidSuffix
{
  [self stubAppID:@" "];
  FBSDKSettings.appURLSchemeSuffix = @"foo";
  NSString *expected = [NSString stringWithFormat:@"fb %@", FBSDKSettings.appURLSchemeSuffix];

  // This is not desired behavior but accurately reflects what is currently written.
  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    expected,
    "Should return an app url scheme derived app id and app url scheme suffix defined in settings"
  );
}

- (void)testAppURLSchemeWithValidAppIdMissingSuffix
{
  [self stubAppID:self.appID];
  FBSDKSettings.appURLSchemeSuffix = nil;
  NSString *expected = [NSString stringWithFormat:@"fb%@", FBSDKSettings.appID];

  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    expected,
    "Should return an app url scheme derived app id and app url scheme suffix defined in settings"
  );
}

- (void)testAppURLSchemeWithValidAppIdInvalidSuffix
{
  [self stubAppID:self.appID];
  FBSDKSettings.appURLSchemeSuffix = @"   ";
  NSString *expected = [NSString stringWithFormat:@"fb%@%@", FBSDKSettings.appID, FBSDKSettings.appURLSchemeSuffix];

  // This is not desired behavior but accurately reflects what is currently written.
  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    expected,
    "Should return an app url scheme derived app id and app url scheme suffix defined in settings"
  );
}

- (void)testAppURLSchemeWithValidAppIdValidSuffix
{
  [self stubAppID:self.appID];
  FBSDKSettings.appURLSchemeSuffix = @"foo";
  NSString *expected = [NSString stringWithFormat:@"fb%@%@", FBSDKSettings.appID, FBSDKSettings.appURLSchemeSuffix];

  XCTAssertEqualObjects(
    [FBSDKInternalUtility appURLScheme],
    expected,
    "Should return an app url scheme derived app id and app url scheme suffix defined in settings"
  );
}

// MARK: - App URL with host

- (void)testAppUrlWithEmptyHost
{
  [self stubAppID:self.appID];
  FBSDKSettings.appURLSchemeSuffix = @"foo";

  NSURL *url = [FBSDKInternalUtility appURLWithHost:@"" path:validPath queryParameters:self.validParameters error:nil];

  XCTAssertNil(url.host, "Should not set an empty host.");
}

- (void)testAppUrlWithValidHost
{
  [self stubAppID:self.appID];
  FBSDKSettings.appURLSchemeSuffix = @"foo";

  NSURL *url = [FBSDKInternalUtility appURLWithHost:@"facebook" path:validPath queryParameters:self.validParameters error:nil];

  XCTAssertEqualObjects(url.host, @"facebook", "Should set the expected host.");
}

// MARK: - Check registered can open url scheme

- (void)testCheckRegisteredCanOpenURLScheme
{
  NSString *scheme = @"foo";

  [FBSDKInternalUtility checkRegisteredCanOpenURLScheme:scheme];

  OCMVerify([self.internalUtilityClassMock isRegisteredCanOpenURLScheme:scheme]);
}

- (void)testCheckRegisteredCanOpenURLSchemeMultipleTimes
{
  NSString *scheme = @"foo";

  [FBSDKInternalUtility checkRegisteredCanOpenURLScheme:scheme];

  // Should only check for a scheme a single time.
  OCMReject([self.internalUtilityClassMock isRegisteredCanOpenURLScheme:scheme]);

  [FBSDKInternalUtility checkRegisteredCanOpenURLScheme:scheme];
}

// MARK: - Dictionary from FBURL

- (void)testWithAuthorizeHostNoParameters
{
  NSURL *url = [[NSURL alloc] initWithString:@"foo://authorize"];
  NSDictionary *parameters = [FBSDKInternalUtility parametersFromFBURL:url];

  XCTAssertEqualObjects(
    parameters,
    @{},
    "Should not extract parameters from a url if there are none"
  );
}

- (void)testWithAuthorizeHostNoFragment
{
  NSURL *url = [[NSURL alloc] initWithString:@"foo://authorize?foo=bar"];
  NSDictionary *parameters = [FBSDKInternalUtility parametersFromFBURL:url];

  XCTAssertEqualObjects(
    parameters,
    @{@"foo" : @"bar"},
    "Should extract parameters from a url"
  );
}

- (void)testWithAuthorizeHostAndFragment
{
  NSURL *url = [[NSURL alloc] initWithString:@"foo://authorize?foo=bar#param1=value1&param2=value2"];
  NSDictionary *parameters = [FBSDKInternalUtility parametersFromFBURL:url];
  NSDictionary *expectedParameters = @{
    @"foo" : @"bar",
    @"param1" : @"value1",
    @"param2" : @"value2"
  };

  XCTAssertEqualObjects(
    parameters,
    expectedParameters,
    "Extracted parameters from an auth url should include fragment parameters"
  );
}

- (void)testWithoutAuthorizeHostNoParameters
{
  NSURL *url = [[NSURL alloc] initWithString:@"foo://example"];
  NSDictionary *parameters = [FBSDKInternalUtility parametersFromFBURL:url];

  XCTAssertEqualObjects(
    parameters,
    @{},
    "Should not extract parameters from a url if there are none"
  );
}

- (void)testWithoutAuthorizeHostNoFragment
{
  NSURL *url = [[NSURL alloc] initWithString:@"foo://example?foo=bar"];
  NSDictionary *parameters = [FBSDKInternalUtility parametersFromFBURL:url];

  XCTAssertEqualObjects(
    parameters,
    @{@"foo" : @"bar"},
    "Should extract parameters from a url"
  );
}

- (void)testWithoutAuthorizeHostWithFragment
{
  NSURL *url = [[NSURL alloc] initWithString:@"foo://example?foo=bar#param1=value1&param2=value2"];
  NSDictionary *parameters = [FBSDKInternalUtility parametersFromFBURL:url];
  NSDictionary *expectedParameters = @{ @"foo" : @"bar" };

  XCTAssertEqualObjects(
    parameters,
    expectedParameters,
    "Extracted parameters from a non auth url should not include fragment parameters"
  );
}

// MARK: - Cookies

- (void)testDeletingDialogCookies
{
  NSHTTPCookie *cookie1 = [self cookieForUrl:self.dialogUrl];
  NSHTTPCookie *cookie2 = [self cookieForUrl:self.dialogUrl name:@"cookie 2"];

  [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:cookie1];
  [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:cookie2];

  NSArray *cookies = [NSHTTPCookieStorage.sharedHTTPCookieStorage cookiesForURL:self.dialogUrl];
  NSArray *expectedCookies = @[cookie1, cookie2];

  XCTAssertEqualObjects(cookies, expectedCookies, "Sanity check that there are cookies to delete");

  [FBSDKInternalUtility deleteFacebookCookies];
  XCTAssertEqual(
    [NSHTTPCookieStorage.sharedHTTPCookieStorage cookiesForURL:self.dialogUrl],
    @[],
    "All cookies for the facebook dialog url should be deleted"
  );
}

- (void)testDeletingNonDialogCookies
{
  NSHTTPCookie *cookie = [self cookieForUrl:self.nonDialogUrl];
  [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:cookie];

  NSArray *cookies = [NSHTTPCookieStorage.sharedHTTPCookieStorage cookiesForURL:self.nonDialogUrl];
  XCTAssertEqualObjects(cookies, @[cookie], "Sanity check that there are cookies to delete");

  [FBSDKInternalUtility deleteFacebookCookies];
  XCTAssertEqualObjects(
    [NSHTTPCookieStorage.sharedHTTPCookieStorage cookiesForURL:self.nonDialogUrl],
    @[cookie],
    "Should only delete cookies for the dialog url"
  );
}

- (void)testDeletingMixOfCookies
{
  NSHTTPCookie *dialogCookie = [self cookieForUrl:self.dialogUrl];
  NSHTTPCookie *nonDialogCookie = [self cookieForUrl:self.nonDialogUrl];

  [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:dialogCookie];
  [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:nonDialogCookie];

  [FBSDKInternalUtility deleteFacebookCookies];

  XCTAssertEqualObjects(
    [NSHTTPCookieStorage.sharedHTTPCookieStorage cookiesForURL:self.dialogUrl],
    @[],
    "Should delete cookies for the dialog url"
  );
  XCTAssertEqualObjects(
    [NSHTTPCookieStorage.sharedHTTPCookieStorage cookiesForURL:self.nonDialogUrl],
    @[nonDialogCookie],
    "Should only delete cookies for the dialog url"
  );
}

// MARK: - App Installation

- (void)testIsRegisteredCanOpenURLSchemeWithMissingScheme
{
  NSArray *querySchemes = @[];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  XCTAssertFalse(
    [FBSDKInternalUtility isRegisteredCanOpenURLScheme:self.name],
    "Should not be consider a scheme to be registered if it's missing from the application query schemes"
  );
}

- (void)testIsRegisteredCanOpenURLSchemeWithScheme
{
  NSArray *querySchemes = @[self.name];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  XCTAssertTrue(
    [FBSDKInternalUtility isRegisteredCanOpenURLScheme:self.name],
    "Should consider a scheme to be registered if it exists in the application query schemes"
  );
}

- (void)testIsRegisteredCanOpenURLSchemeCache
{
  NSArray *querySchemes = @[self.name];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  XCTAssertTrue([FBSDKInternalUtility isRegisteredCanOpenURLScheme:self.name], "Sanity check");

  [bundle setInfoDictionary:@{}];

  XCTAssertTrue([FBSDKInternalUtility isRegisteredCanOpenURLScheme:self.name], "Should return the cached value of the main bundle and not the updated values");
}

- (void)testFacebookAppInstalledMissingQuerySchemes
{
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isFacebookAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:facebookUrlSchemeMissingMessage]);
}

- (void)testFacebookAppInstalledEmptyQuerySchemes
{
  NSArray *querySchemes = @[];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isFacebookAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:facebookUrlSchemeMissingMessage]);
}

- (void)testFacebookAppInstalledMissingQueryScheme
{
  NSArray *querySchemes = @[@"Foo"];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isFacebookAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:facebookUrlSchemeMissingMessage]);
}

- (void)testFacebookAppInstalledValidQueryScheme
{
  NSArray *querySchemes = @[@"fbauth2"];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  OCMReject([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:OCMArg.any]);

  [FBSDKInternalUtility isFacebookAppInstalled];
}

- (void)testFacebookAppInstalledCache
{
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isFacebookAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:facebookUrlSchemeMissingMessage]);
  OCMReject([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:OCMArg.any]);

  [FBSDKInternalUtility isFacebookAppInstalled];
}

- (void)testMessengerAppInstalledMissingQuerySchemes
{
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isMessengerAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:messengerUrlSchemeMissingMessage]);
}

- (void)testMessengerAppInstalledEmptyQuerySchemes
{
  NSArray *querySchemes = @[];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isMessengerAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:messengerUrlSchemeMissingMessage]);
}

- (void)testMessengerAppInstalledMissingQueryScheme
{
  NSArray *querySchemes = @[@"Foo"];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isMessengerAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:messengerUrlSchemeMissingMessage]);
}

- (void)testMessengerAppInstalledValidQueryScheme
{
  NSArray *querySchemes = @[@"fb-messenger-share-api"];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  OCMReject([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:OCMArg.any]);

  [FBSDKInternalUtility isMessengerAppInstalled];
}

- (void)testMessengerAppInstalledCache
{
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isMessengerAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:messengerUrlSchemeMissingMessage]);
  OCMReject([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:OCMArg.any]);

  [FBSDKInternalUtility isMessengerAppInstalled];
}

- (void)testMSQRDPlayerAppInstalledMissingQuerySchemes
{
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isMSQRDPlayerAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:msqrdPlayerUrlSchemeMissingMessage]);
}

- (void)testMSQRDPlayerAppInstalledEmptyQuerySchemes
{
  NSArray *querySchemes = @[];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isMSQRDPlayerAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:msqrdPlayerUrlSchemeMissingMessage]);
}

- (void)testMSQRDPlayerAppInstalledMissingQueryScheme
{
  NSArray *querySchemes = @[@"Foo"];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isMSQRDPlayerAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:msqrdPlayerUrlSchemeMissingMessage]);
}

- (void)testMSQRDPlayerAppInstalledValidQueryScheme
{
  NSArray *querySchemes = @[@"msqrdplayer"];
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{@"LSApplicationQueriesSchemes" : querySchemes}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  OCMReject([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:OCMArg.any]);

  [FBSDKInternalUtility isMSQRDPlayerAppInstalled];
}

- (void)testMSQRDPlayerAppInstalledCache
{
  id bundle = [[TestBundle alloc] initWithInfoDictionary:@{}];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isMSQRDPlayerAppInstalled];

  OCMVerify([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:msqrdPlayerUrlSchemeMissingMessage]);
  OCMReject([self.loggerClassMock singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:OCMArg.any]);

  [FBSDKInternalUtility isMSQRDPlayerAppInstalled];
}

// MARK: - Random Utility Methods

- (void)testIsBrowserURLWithNonBrowserURL
{
  NSArray *urls = @[
    [NSURL URLWithString:@"file://foo"],
    [NSURL URLWithString:@"example://bar"]
  ];

  for (NSURL *url in urls) {
    XCTAssertFalse([FBSDKInternalUtility isBrowserURL:url], "%@ should not be considered a browser url", url.absoluteString);
  }
}

- (void)testIsBrowserURLWithBrowserURL
{
  NSArray *urls = @[
    [NSURL URLWithString:@"HTTPS://example.com"],
    [NSURL URLWithString:@"HTTP://example.com"],
    [NSURL URLWithString:@"https://example.com"],
    [NSURL URLWithString:@"http://example.com"],
  ];

  for (NSURL *url in urls) {
    XCTAssertTrue([FBSDKInternalUtility isBrowserURL:url], "%@ should be considered a browser url", url.absoluteString);
  }
}

- (void)testIsFacebookBundleIdentifierWithInvalidIdentifiers
{
  NSArray *identifiers = @[
    @"",
    @"foo",
    @"com.foo.bar",
    @"com.facebook"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertFalse([FBSDKInternalUtility isFacebookBundleIdentifier:identifier], "%@ should not be considered a facebook bundle indentifier", identifier);
  }
}

- (void)testIsFacebookBundleIdentifierWithValidIdentifiers
{
  NSArray *identifiers = @[
    @"com.facebook.",
    @"com.facebook.foo",
    @".com.facebook.",
    @".com.facebook.foo"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertTrue([FBSDKInternalUtility isFacebookBundleIdentifier:identifier], "%@ should be considered a facebook bundle indentifier", identifier);
  }
}

- (void)testNonSafariBundleIdentifiers
{
  NSArray *identifiers = @[
    @"",
    @" ",
    @"com.foo"
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertFalse(
      [FBSDKInternalUtility isSafariBundleIdentifier:identifier],
      "%@ should not be considered a safari bundle identifier",
      identifier
    );
  }
}

- (void)testSafariBundleIdentifiers
{
  NSArray *identifiers = @[
    @"com.apple.mobilesafari",
    @"com.apple.SafariViewService",
  ];

  for (NSString *identifier in identifiers) {
    XCTAssertTrue(
      [FBSDKInternalUtility isSafariBundleIdentifier:identifier],
      "%@ should be considered a safari bundle identifier",
      identifier
    );
  }
}

- (void)testValidatingAppID
{
  [self stubAppID:nil];

  XCTAssertThrows([FBSDKInternalUtility validateAppID]);
}

- (void)testValidateClientAccessTokenWithoutClientTokenWithoutAppID
{
  [self stubAppID:nil];
  FBSDKSettings.clientToken = nil;

  XCTAssertThrows([FBSDKInternalUtility validateRequiredClientAccessToken]);
}

- (void)testValidateClientAccessTokenWithClientTokenWithoutAppID
{
  [self stubAppID:nil];
  FBSDKSettings.clientToken = @"client123";

  XCTAssertEqualObjects(
    [FBSDKInternalUtility validateRequiredClientAccessToken],
    @"(null)|client123",
    "A valid client-access token should include the app identifier and the client token"
  );
}

- (void)testValidateClientAccessTokenWithClientTokenWithAppID
{
  [self stubAppID:self.appID];
  FBSDKSettings.clientToken = @"client123";

  XCTAssertEqualObjects(
    [FBSDKInternalUtility validateRequiredClientAccessToken],
    @"appid|client123",
    "A valid client-access token should include the app identifier and the client token"
  );
}

- (void)testValidateClientAccessTokenWithoutClientTokenWithAppID
{
  [self stubAppID:self.appID];
  FBSDKSettings.clientToken = nil;

  XCTAssertThrows([FBSDKInternalUtility validateRequiredClientAccessToken]);
}

- (void)testIsRegisteredUrlSchemeWithRegisteredScheme
{
  TestBundle *bundle = [self bundleWithRegisteredUrlSchemes:@[@"com.foo.bar"]];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  XCTAssertTrue([FBSDKInternalUtility isRegisteredURLScheme:@"com.foo.bar"], "Schemes in the bundle should be considered registered");
}

- (void)testIsRegisteredUrlSchemeWithoutRegisteredScheme
{
  TestBundle *bundle = [self bundleWithRegisteredUrlSchemes:@[@"com.foo.bar"]];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  XCTAssertFalse([FBSDKInternalUtility isRegisteredURLScheme:@"com.facebook"], "Schemes absent from the bundle should not be considered registered");
}

- (void)testIsRegisteredUrlSchemeCaching
{
  TestBundle *bundle = [TestBundle new];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  [FBSDKInternalUtility isRegisteredURLScheme:@"com.facebook"];

  XCTAssertTrue(
    bundle.didAccessInfoDictionary,
    "Should query the bundle for URL types"
  );
  [bundle reset];

  [FBSDKInternalUtility isRegisteredURLScheme:@"com.facebook"];

  XCTAssertFalse(
    bundle.didAccessInfoDictionary,
    "Should not query the bundle more than once"
  );
}

- (void)testValidatingUrlSchemesWithoutAppID
{
  [self stubAppID:nil];

  XCTAssertThrows(
    [FBSDKInternalUtility validateURLSchemes],
    "Cannot validate url schemes without an app identifier"
  );
}

- (void)testValidatingUrlSchemesWithAppIdMatchingBundleEntry
{
  [self stubAppID:self.appID];
  FBSDKSettings.appURLSchemeSuffix = nil;

  TestBundle *bundle = [self bundleWithRegisteredUrlSchemes:@[@"fbappid"]];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  XCTAssertNoThrow(
    [FBSDKInternalUtility validateURLSchemes],
    "The registered app url scheme must match the app id and url scheme suffix prepended with 'fb'"
  );
}

- (void)testValidatingUrlSchemesWithNonAppIdMatchingBundleEntry
{
  [self stubAppID:self.appID];
  FBSDKSettings.appURLSchemeSuffix = nil;

  TestBundle *bundle = [self bundleWithRegisteredUrlSchemes:@[@"fb123"]];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;

  XCTAssertThrows(
    [FBSDKInternalUtility validateURLSchemes],
    "The registered app url scheme must match the app id and url scheme suffix prepended with 'fb'"
  );
}

// We can't loop through these because of how stubbing works.
- (void)testValidatingFacebookUrlSchemes_auth
{
  TestBundle *bundle = [self bundleWithRegisteredUrlSchemes:@[@"fbauth2"]];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;
  XCTAssertThrows([FBSDKInternalUtility validateFacebookReservedURLSchemes], "Should throw an error if fbauth2 is present in the bundle url schemes");
}

// We can't loop through these because of how stubbing works.
- (void)testValidatingFacebookUrlSchemes_api
{
  TestBundle *bundle = [self bundleWithRegisteredUrlSchemes:@[@"fbapi"]];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;
  XCTAssertThrows([FBSDKInternalUtility validateFacebookReservedURLSchemes], "Should throw an error if fbapi is present in the bundle url schemes");
}

// We can't loop through these because of how stubbing works.
- (void)testValidatingFacebookUrlSchemes_messenger
{
  TestBundle *bundle = [self bundleWithRegisteredUrlSchemes:@[@"fb-messenger-share-api"]];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;
  XCTAssertThrows([FBSDKInternalUtility validateFacebookReservedURLSchemes], "Should throw an error if fb-messenger-share-api is present in the bundle url schemes");
}

// We can't loop through these because of how stubbing works.
- (void)testValidatingFacebookUrlSchemes_shareextension
{
  TestBundle *bundle = [self bundleWithRegisteredUrlSchemes:@[@"fbshareextension"]];
  FBSDKInternalUtility.infoDictionaryProvider = bundle;
  XCTAssertThrows([FBSDKInternalUtility validateFacebookReservedURLSchemes], "Should throw an error if fbshareextension is present in the bundle url schemes");
}

- (void)testIsPublishPermission
{
  NSArray *publishPermissions = @[
    @"publish",
    @"publishSomething",
    @"manage",
    @"manageSomething",
    @"ads_management",
    @"create_event",
    @"rsvp_event"
  ];
  for (NSString *permission in publishPermissions) {
    XCTAssertTrue([FBSDKInternalUtility isPublishPermission:permission]);
  }

  NSArray *nonPublishPermissions = @[
    @"",
    @"email",
    @"_publish"
  ];
  for (NSString *permission in nonPublishPermissions) {
    XCTAssertFalse([FBSDKInternalUtility isPublishPermission:permission]);
  }
}

- (void)testIsUnityWithMissingSuffix
{
  FBSDKSettings.userAgentSuffix = nil;
  XCTAssertFalse([FBSDKInternalUtility isUnity], "User agent should determine whether an app is Unity");
}

- (void)testIsUnityWithNonUnitySuffix
{
  FBSDKSettings.userAgentSuffix = @"Foo";
  XCTAssertFalse([FBSDKInternalUtility isUnity], "User agent should determine whether an app is Unity");
}

- (void)testIsUnityWithUnitySuffix
{
  FBSDKSettings.userAgentSuffix = @"__Unity__";
  XCTAssertTrue([FBSDKInternalUtility isUnity], "User agent should determine whether an app is Unity");
}

- (void)testHexadecimalStringFromData
{
  XCTAssertNil([FBSDKInternalUtility hexadecimalStringFromData:NSData.data]);

  NSString *foo = @"foo";
  NSData *stringData = [foo dataUsingEncoding:NSUTF8StringEncoding];
  NSString *expected = @"666f6f";

  XCTAssertEqualObjects([FBSDKInternalUtility hexadecimalStringFromData:stringData], expected);
}

- (void)testObjectIsEqualToObject
{
  id obj1 = @"foo";
  id obj2 = @"foo";
  id obj3 = @"bar";

  XCTAssertTrue([FBSDKInternalUtility object:obj1 isEqualToObject:obj1]);
  XCTAssertTrue([FBSDKInternalUtility object:obj1 isEqualToObject:obj2]);
  XCTAssertFalse([FBSDKInternalUtility object:obj1 isEqualToObject:obj3]);

  obj1 = nil;
  XCTAssertFalse([FBSDKInternalUtility object:obj1 isEqualToObject:obj2]);
  XCTAssertFalse([FBSDKInternalUtility object:obj2 isEqualToObject:obj1]);
}

- (void)testCreatingUrlWithUnknownError // InvalidQueryString
{
  NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

  [FBSDKInternalUtility URLWithScheme:@"https" host:@"example" path:@"/foo" queryParameters:@{@"a date" : NSDate.date} error:&error];

  XCTAssertEqualObjects(
    error.domain,
    @"com.facebook.sdk.core",
    "Creating a url with an error reference should repopulate the error domain correctly"
  );
  XCTAssertEqual(
    error.code,
    3,
    "Creating a url with an error reference should repopulate the error code correctly"
  );
  XCTAssertEqualObjects(
    [error.userInfo objectForKey:FBSDKErrorDeveloperMessageKey],
    @"Unknown error building URL.",
    "Creating a url with an error reference should repopulate the error message correctly"
  );
}

- (void)testCreatingUrlWithInvalidQueryString
{
  NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

  [FBSDKInternalUtility URLWithScheme:@"https" host:@"example" path:@"/foo" queryParameters:@{@[] : @"foo"} error:&error];

  XCTAssertEqualObjects(
    error.domain,
    @"com.facebook.sdk.core",
    "Creating a url with invalid parameters should repopulate the error domain correctly"
  );
  XCTAssertEqual(
    error.code,
    2,
    "Creating a url with invalid parameters should repopulate the error code correctly"
  );

  XCTAssertTrue(
    [[error.userInfo objectForKey:FBSDKErrorDeveloperMessageKey] hasPrefix:@"Invalid value for queryParameters:"],
    "Creating a url with invalid parameters should repopulate the error message correctly"
  );
}

// MARK: - Helpers

- (NSURL *)dialogUrl
{
  return [FBSDKInternalUtility facebookURLWithHostPrefix:@"m."
                                                    path:@"/dialog/"
                                         queryParameters:@{}
                                                   error:NULL];
}

- (NSURL *)nonDialogUrl
{
  return [FBSDKInternalUtility facebookURLWithHostPrefix:@"m."
                                                    path:@"/foo/"
                                         queryParameters:@{}
                                                   error:NULL];
}

- (NSHTTPCookie *)cookieForUrl:(NSURL *)url name:(NSString *)name
{
  return [NSHTTPCookie cookieWithProperties:@{
            NSHTTPCookieOriginURL : url,
            NSHTTPCookiePath : url.path,
            NSHTTPCookieName : name,
            NSHTTPCookieValue : @"Is good"
          }];
}

- (NSHTTPCookie *)cookieForUrl:(NSURL *)url
{
  return [self cookieForUrl:url name:@"MyCookie"];
}

- (NSDictionary *)validParameters
{
  return @{@"foo" : @"bar"};
}

NSString *const validPath = @"example";
NSString *const facebookUrlSchemeMissingMessage = @"fbauth2 is missing from your Info.plist under LSApplicationQueriesSchemes and is required.";
NSString *const messengerUrlSchemeMissingMessage = @"fb-messenger-share-api is missing from your Info.plist under LSApplicationQueriesSchemes and is required.";
NSString *const msqrdPlayerUrlSchemeMissingMessage = @"msqrdplayer is missing from your Info.plist under LSApplicationQueriesSchemes and is required.";

- (TestBundle *)bundleWithRegisteredUrlSchemes:(NSArray<NSString *> *)schemes
{
  return [[TestBundle alloc] initWithInfoDictionary:@{
            @"CFBundleURLTypes" : @[
              @{ @"CFBundleURLSchemes" : schemes }
            ]
          }];
}

@end
