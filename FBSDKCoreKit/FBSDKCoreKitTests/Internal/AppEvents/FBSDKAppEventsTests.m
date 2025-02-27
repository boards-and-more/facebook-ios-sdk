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
#import <XCTest/XCTest.h>

@import TestTools;

#import "FBSDKAccessToken.h"
#import "FBSDKAppEvents.h"
#import "FBSDKAppEvents+Internal.h"
#import "FBSDKAppEventsConfigurationProviding.h"
#import "FBSDKAppEventsState.h"
#import "FBSDKAppEventsUtility.h"
#import "FBSDKApplicationDelegate.h"
#import "FBSDKConstants.h"
#import "FBSDKCoreKitTests-Swift.h"
#import "FBSDKGateKeeperManager.h"
#import "FBSDKGraphRequestProtocol.h"
#import "FBSDKInternalUtility.h"
#import "FBSDKLogger.h"
#import "FBSDKServerConfigurationFixtures.h"
#import "FBSDKSettings.h"
#import "FBSDKTestCase.h"
#import "FBSDKUtility.h"
#import "UserDefaultsSpy.h"

static NSString *const _mockAppID = @"mockAppID";
static NSString *const _mockUserID = @"mockUserID";

// An extension that redeclares a private method so that it can be mocked
@interface FBSDKApplicationDelegate (Testing)
- (void)_logSDKInitialize;
@end

@interface FBSDKAppEvents (Testing)
@property (nonatomic, copy) NSString *pushNotificationsDeviceTokenString;
@property (nonatomic, strong) id<FBSDKAtePublishing> atePublisher;

- (void)publishInstall;
- (void)flushForReason:(FBSDKAppEventsFlushReason)flushReason;
- (void)fetchServerConfiguration:(FBSDKCodeBlock)callback;
- (void)instanceLogEvent:(FBSDKAppEventName)eventName
              valueToSum:(NSNumber *)valueToSum
              parameters:(NSDictionary<NSString *, id> *)parameters
      isImplicitlyLogged:(BOOL)isImplicitlyLogged
             accessToken:(FBSDKAccessToken *)accessToken;
- (void)applicationDidBecomeActive;
- (void)applicationMovingFromActiveStateOrTerminating;
- (void)setFlushBehavior:(FBSDKAppEventsFlushBehavior)flushBehavior;

+ (FBSDKAppEvents *)singleton;

+ (void)reset;

+ (void)setCanLogEvents;

+ (BOOL)canLogEvents;

+ (UIApplicationState)applicationState;

+ (void)logInternalEvent:(FBSDKAppEventName)eventName
      isImplicitlyLogged:(BOOL)isImplicitlyLogged;

+ (void)logInternalEvent:(FBSDKAppEventName)eventName
              valueToSum:(double)valueToSum
      isImplicitlyLogged:(BOOL)isImplicitlyLogged;

+ (void)logInternalEvent:(FBSDKAppEventName)eventName
              valueToSum:(double)valueToSum
              parameters:(NSDictionary<NSString *, id> *)parameters
      isImplicitlyLogged:(BOOL)isImplicitlyLogged;

+ (void)logInternalEvent:(NSString *)eventName
              valueToSum:(NSNumber *)valueToSum
              parameters:(NSDictionary<NSString *, id> *)parameters
      isImplicitlyLogged:(BOOL)isImplicitlyLogged
             accessToken:(FBSDKAccessToken *)accessToken;

+ (void)logInternalEvent:(NSString *)eventName
              parameters:(NSDictionary<NSString *, id> *)parameters
      isImplicitlyLogged:(BOOL)isImplicitlyLogged
             accessToken:(FBSDKAccessToken *)accessToken;

+ (void)logImplicitEvent:(NSString *)eventName
              valueToSum:(NSNumber *)valueToSum
              parameters:(NSDictionary<NSString *, id> *)parameters
             accessToken:(FBSDKAccessToken *)accessToken;

@end

@interface FBSDKAppEventsTests : FBSDKTestCase
{
  NSString *_mockEventName;
  NSDictionary<NSString *, id> *_mockPayload;
  double _mockPurchaseAmount;
  NSString *_mockCurrency;
  TestGraphRequestFactory *_graphRequestFactory;
  UserDefaultsSpy *_store;
  TestFeatureManager *_featureManager;
  TestSettings *_settings;
  TestOnDeviceMLModelManager *_onDeviceMLModelManager;
  TestPaymentObserver *_paymentObserver;
  TestTimeSpentRecorder *_timeSpentRecorder;
  TestAppEventsStateStore *_appEventsStateStore;
  TestMetadataIndexer *_metadataIndexer;
  TestAppEventsParameterProcessor *_eventDeactivationParameterProcessor;
  TestAppEventsParameterProcessor *_restrictiveDataFilterParameterProcessor;
}

@property (nonnull, nonatomic) TestAtePublisherFactory *atePublisherfactory;
@property (nonnull, nonatomic) TestAtePublisher *atePublisher;

@end

@implementation FBSDKAppEventsTests

+ (void)setUp
{
  [super setUp];

  [FBSDKAppEvents reset];
}

- (void)setUp
{
  self.shouldAppEventsMockBePartial = YES;

  [super setUp];
  [self resetTestHelpers];
  [FBSDKSettings reset];
  _settings = [TestSettings new];
  _settings.stubbedIsAutoLogAppEventsEnabled = YES;
  [FBSDKInternalUtility reset];
  _onDeviceMLModelManager = [TestOnDeviceMLModelManager new];
  _onDeviceMLModelManager.integrityParametersProcessor = [TestAppEventsParameterProcessor new];
  _paymentObserver = [TestPaymentObserver new];
  _timeSpentRecorder = [TestTimeSpentRecorder new];
  _metadataIndexer = [TestMetadataIndexer new];

  [self stubLoadingAdNetworkReporterConfiguration];
  [self stubServerConfigurationFetchingWithConfiguration:FBSDKServerConfigurationFixtures.defaultConfig error:nil];

  _mockEventName = @"fb_mock_event";
  _mockPayload = @{@"fb_push_payload" : @{@"campaign" : @"testCampaign"}};
  _mockPurchaseAmount = 1.0;
  _mockCurrency = @"USD";
  _graphRequestFactory = [TestGraphRequestFactory new];
  _store = [UserDefaultsSpy new];
  _featureManager = [TestFeatureManager new];
  _paymentObserver = [TestPaymentObserver new];
  _appEventsStateStore = [TestAppEventsStateStore new];
  _eventDeactivationParameterProcessor = [TestAppEventsParameterProcessor new];
  _restrictiveDataFilterParameterProcessor = [TestAppEventsParameterProcessor new];
  self.atePublisherfactory = [TestAtePublisherFactory new];

  [FBSDKAppEvents setLoggingOverrideAppID:_mockAppID];

  // Mock FBSDKAppEventsUtility methods
  [self stubAppEventsUtilityShouldDropAppEventWith:NO];

  // Must be stubbed before the configure method is called
  self.atePublisher = [TestAtePublisher new];
  self.atePublisherfactory.stubbedPublisher = self.atePublisher;

  // This should be removed when these tests are updated to check the actual requests that are created
  [self stubAllocatingGraphRequestConnection];
  [FBSDKAppEvents.singleton configureWithGateKeeperManager:TestGateKeeperManager.class
                            appEventsConfigurationProvider:TestAppEventsConfigurationProvider.class
                               serverConfigurationProvider:TestServerConfigurationProvider.class
                                      graphRequestProvider:_graphRequestFactory
                                            featureChecker:_featureManager
                                                     store:_store
                                                    logger:TestLogger.class
                                                  settings:_settings
                                           paymentObserver:_paymentObserver
                                         timeSpentRecorder:_timeSpentRecorder
                                       appEventsStateStore:_appEventsStateStore
                       eventDeactivationParameterProcessor:_eventDeactivationParameterProcessor
                   restrictiveDataFilterParameterProcessor:_restrictiveDataFilterParameterProcessor
                                       atePublisherFactory:self.atePublisherfactory];

  [FBSDKAppEvents configureNonTVComponentsWithOnDeviceMLModelManager:_onDeviceMLModelManager
                                                     metadataIndexer:_metadataIndexer];
}

- (void)tearDown
{
  [super tearDown];
  [FBSDKAppEvents reset];
  [TestAppEventsConfigurationProvider reset];
  [TestServerConfigurationProvider reset];
  [TestGateKeeperManager reset];
}

- (void)resetTestHelpers
{
  [TestSettings reset];
  [TestLogger reset];
}

- (void)testInitializingCreatesAtePublisher
{
  XCTAssertEqualObjects(
    self.atePublisherfactory.capturedAppID,
    _mockAppID,
    "Initializing should create an ate publisher with the expected app id"
  );
  XCTAssertEqualObjects(
    FBSDKAppEvents.singleton.atePublisher,
    self.atePublisher,
    "Should store the publisher created by the publisher factory"
  );
}

- (void)testAppEventsMockIsSingleton
{
  XCTAssertEqual(self.appEventsMock, [FBSDKAppEvents singleton]);
}

- (void)testLogPurchaseFlush
{
  OCMExpect([self.appEventsMock flushForReason:FBSDKAppEventsFlushReasonEagerlyFlushingEvent]);

  OCMStub([self.appEventsMock flushBehavior]).andReturn(FBSDKAppEventsFlushReasonEagerlyFlushingEvent);

  [FBSDKAppEvents logPurchase:_mockPurchaseAmount currency:_mockCurrency];

  OCMVerifyAll(self.appEventsMock);
}

- (void)testLogPurchase
{
  OCMExpect([self.appEventsMock logPurchase:_mockPurchaseAmount currency:_mockCurrency parameters:[OCMArg any]]).andForwardToRealObject();
  OCMExpect([self.appEventsMock logPurchase:_mockPurchaseAmount currency:_mockCurrency parameters:[OCMArg any] accessToken:[OCMArg any]]).andForwardToRealObject();
  OCMExpect([self.appEventsMock logEvent:FBSDKAppEventNamePurchased valueToSum:@(_mockPurchaseAmount) parameters:[OCMArg any] accessToken:[OCMArg any]]).andForwardToRealObject();
  OCMExpect([self.appEventStatesMock addEvent:[OCMArg any] isImplicit:NO]);

  [FBSDKAppEvents logPurchase:_mockPurchaseAmount currency:_mockCurrency];

  OCMVerifyAll(self.appEventsMock);
  [self.appEventStatesMock verify];
}

- (void)testFlush
{
  OCMExpect([self.appEventsMock flushForReason:FBSDKAppEventsFlushReasonExplicit]);

  [FBSDKAppEvents flush];

  OCMVerifyAll(self.appEventsMock);
}

#pragma mark  Tests for log product item

- (void)testLogProductItemNonNil
{
  NSDictionary<NSString *, NSString *> *expectedDict = @{
    @"fb_product_availability" : @"IN_STOCK",
    @"fb_product_brand" : @"PHILZ",
    @"fb_product_condition" : @"NEW",
    @"fb_product_description" : @"description",
    @"fb_product_gtin" : @"BLUE MOUNTAIN",
    @"fb_product_image_link" : @"https://www.sample.com",
    @"fb_product_item_id" : @"F40CEE4E-471E-45DB-8541-1526043F4B21",
    @"fb_product_link" : @"https://www.sample.com",
    @"fb_product_mpn" : @"BLUE MOUNTAIN",
    @"fb_product_price_amount" : @"1.000",
    @"fb_product_price_currency" : @"USD",
    @"fb_product_title" : @"title",
  };
  OCMExpect(
    [self.appEventsMock logEvent:@"fb_mobile_catalog_update"
                      parameters:expectedDict]
  );

  [FBSDKAppEvents logProductItem:@"F40CEE4E-471E-45DB-8541-1526043F4B21"
                    availability:FBSDKProductAvailabilityInStock
                       condition:FBSDKProductConditionNew
                     description:@"description"
                       imageLink:@"https://www.sample.com"
                            link:@"https://www.sample.com"
                           title:@"title"
                     priceAmount:1.0
                        currency:@"USD"
                            gtin:@"BLUE MOUNTAIN"
                             mpn:@"BLUE MOUNTAIN"
                           brand:@"PHILZ"
                      parameters:@{}];

  OCMVerifyAll(self.appEventsMock);
}

- (void)testLogProductItemNilGtinMpnBrand
{
  NSDictionary<NSString *, NSString *> *expectedDict = @{
    @"fb_product_availability" : @"IN_STOCK",
    @"fb_product_condition" : @"NEW",
    @"fb_product_description" : @"description",
    @"fb_product_image_link" : @"https://www.sample.com",
    @"fb_product_item_id" : @"F40CEE4E-471E-45DB-8541-1526043F4B21",
    @"fb_product_link" : @"https://www.sample.com",
    @"fb_product_price_amount" : @"1.000",
    @"fb_product_price_currency" : @"USD",
    @"fb_product_title" : @"title",
  };
  OCMReject(
    [self.appEventsMock logEvent:@"fb_mobile_catalog_update"
                      parameters:expectedDict]
  );

  [FBSDKAppEvents logProductItem:@"F40CEE4E-471E-45DB-8541-1526043F4B21"
                    availability:FBSDKProductAvailabilityInStock
                       condition:FBSDKProductConditionNew
                     description:@"description"
                       imageLink:@"https://www.sample.com"
                            link:@"https://www.sample.com"
                           title:@"title"
                     priceAmount:1.0
                        currency:@"USD"
                            gtin:nil
                             mpn:nil
                           brand:nil
                      parameters:@{}];

  XCTAssertEqual(
    TestLogger.capturedLoggingBehavior,
    FBSDKLoggingBehaviorDeveloperErrors,
    "A log entry of LoggingBehaviorDeveloperErrors should be posted when some parameters are nil for logProductItem"
  );
}

#pragma mark  Tests for set and clear user data

- (void)testSetAndClearUserData
{
  NSString *mockEmail = @"test_em";
  NSString *mockFirstName = @"test_fn";
  NSString *mockLastName = @"test_ln";
  NSString *mockPhone = @"123";

  [FBSDKAppEvents setUserEmail:mockEmail
                     firstName:mockFirstName
                      lastName:mockLastName
                         phone:mockPhone
                   dateOfBirth:nil
                        gender:nil
                          city:nil
                         state:nil
                           zip:nil
                       country:nil];

  NSDictionary<NSString *, NSString *> *expectedUserData = @{@"em" : [FBSDKUtility SHA256Hash:mockEmail],
                                                             @"fn" : [FBSDKUtility SHA256Hash:mockFirstName],
                                                             @"ln" : [FBSDKUtility SHA256Hash:mockLastName],
                                                             @"ph" : [FBSDKUtility SHA256Hash:mockPhone], };
  NSDictionary<NSString *, NSString *> *userData = (NSDictionary<NSString *, NSString *> *)[FBSDKTypeUtility JSONObjectWithData:[[FBSDKAppEvents getUserData] dataUsingEncoding:NSUTF8StringEncoding]
                                                                                          options: NSJSONReadingMutableContainers
                                                                                          error: nil];
  XCTAssertEqualObjects(userData, expectedUserData);

  [FBSDKAppEvents clearUserData];
  NSString *clearedUserData = [FBSDKAppEvents getUserData];
  XCTAssertEqualObjects(clearedUserData, @"{}");
}

- (void)testSetAndClearUserDataForType
{
  NSString *testEmail = @"apptest@fb.com";
  NSString *hashedEmailString = [FBSDKUtility SHA256Hash:testEmail];

  [FBSDKAppEvents setUserData:testEmail forType:FBSDKAppEventEmail];
  NSString *userData = [FBSDKAppEvents getUserData];
  XCTAssertTrue([userData containsString:@"em"]);
  XCTAssertTrue([userData containsString:hashedEmailString]);

  [FBSDKAppEvents clearUserDataForType:FBSDKAppEventEmail];
  userData = [FBSDKAppEvents getUserData];
  XCTAssertFalse([userData containsString:@"em"]);
  XCTAssertFalse([userData containsString:hashedEmailString]);
}

- (void)testSetAndClearUserID
{
  [FBSDKAppEvents setUserID:_mockUserID];
  XCTAssertEqualObjects([FBSDKAppEvents userID], _mockUserID);
  [FBSDKAppEvents clearUserID];
  XCTAssertNil([FBSDKAppEvents userID]);
}

- (void)testSetLoggingOverrideAppID
{
  NSString *mockOverrideAppID = @"2";
  [FBSDKAppEvents setLoggingOverrideAppID:mockOverrideAppID];
  XCTAssertEqualObjects([FBSDKAppEvents loggingOverrideAppID], mockOverrideAppID);
}

- (void)testSetPushNotificationsDeviceTokenString
{
  NSString *mockDeviceTokenString = @"testDeviceTokenString";
  NSString *eventName = @"fb_mobile_obtain_push_token";

  OCMExpect([self.appEventsMock logEvent:eventName]).andForwardToRealObject();
  OCMExpect(
    [self.appEventsMock logEvent:eventName
                      parameters:@{}]
  ).andForwardToRealObject();
  OCMExpect(
    [self.appEventsMock logEvent:eventName
                      valueToSum:nil
                      parameters:@{}
                     accessToken:nil]
  ).andForwardToRealObject();

  [FBSDKAppEvents setPushNotificationsDeviceTokenString:mockDeviceTokenString];

  OCMVerifyAll(self.appEventsMock);

  XCTAssertEqualObjects([FBSDKAppEvents singleton].pushNotificationsDeviceTokenString, mockDeviceTokenString);
}

- (void)testActivateAppWithInitializedSDK
{
  [FBSDKAppEvents setCanLogEvents];

  OCMExpect([self.appEventsMock publishInstall]);
  OCMExpect([self.appEventsMock fetchServerConfiguration:NULL]);

  [FBSDKAppEvents.singleton activateApp];

  OCMVerifyAll(self.appEventsMock);
  XCTAssertTrue(
    _timeSpentRecorder.restoreWasCalled,
    "Activating App with initialized SDK should restore recording time spent data."
  );
  XCTAssertTrue(
    _timeSpentRecorder.capturedCalledFromActivateApp,
    "Activating App with initialized SDK should indicate its calling from activateApp when restoring recording time spent data."
  );
}

- (void)testApplicationBecomingActiveRestoresTimeSpentRecording
{
  FBSDKAppEvents *events = (FBSDKAppEvents *)[(NSObject *)[FBSDKAppEvents alloc] init];
  [events applicationDidBecomeActive];
  XCTAssertTrue(
    _timeSpentRecorder.restoreWasCalled,
    "When application did become active, the time spent recording should be restored."
  );
  XCTAssertFalse(
    _timeSpentRecorder.capturedCalledFromActivateApp,
    "When application did become active, the time spent recording restoration should be indicated that it's not activating."
  );
}

- (void)testApplicationTerminatingSuspendsTimeSpentRecording
{
  FBSDKAppEvents *events = (FBSDKAppEvents *)[(NSObject *)[FBSDKAppEvents alloc] init];
  [events applicationMovingFromActiveStateOrTerminating];
  XCTAssertTrue(
    _timeSpentRecorder.suspendWasCalled,
    "When application terminates or moves from active state, the time spent recording should be suspended."
  );
}

- (void)testApplicationTerminatingPersistingStates
{
  FBSDKAppEvents *events = (FBSDKAppEvents *)[(NSObject *)[FBSDKAppEvents alloc] init];
  [events setFlushBehavior:FBSDKAppEventsFlushBehaviorExplicitOnly];
  [events instanceLogEvent:_mockEventName
                valueToSum:@(_mockPurchaseAmount)
                parameters:nil
        isImplicitlyLogged:NO
               accessToken:nil];
  [events instanceLogEvent:_mockEventName
                valueToSum:@(_mockPurchaseAmount)
                parameters:nil
        isImplicitlyLogged:NO
               accessToken:nil];
  [events applicationMovingFromActiveStateOrTerminating];

  XCTAssertTrue(
    _appEventsStateStore.capturedPersistedState.count > 0,
    "When application terminates or moves from active state, the existing state should be persisted."
  );
}

- (void)testActivateAppWithoutInitializedSDK
{
  [FBSDKAppEvents reset];
  [FBSDKAppEvents.singleton activateApp];

  OCMReject([self.appEventsMock publishInstall]);
  OCMReject([self.appEventsMock fetchServerConfiguration:NULL]);

  XCTAssertFalse(
    _timeSpentRecorder.restoreWasCalled,
    "Activating App without initialized SDK cannot restore recording time spent data."
  );
}

- (void)testInstanceLogEventFilteringOutDeactivatedParameters
{
  NSDictionary<NSString *, id> *parameters = @{@"key" : @"value"};
  [FBSDKAppEvents.singleton instanceLogEvent:_mockEventName
                                  valueToSum:@(_mockPurchaseAmount)
                                  parameters:parameters
                          isImplicitlyLogged:NO
                                 accessToken:nil];
  XCTAssertEqualObjects(
    _eventDeactivationParameterProcessor.capturedEventName,
    _mockEventName,
    "AppEvents instance should submit the event name to event deactivation parameters processor."
  );
  XCTAssertEqualObjects(
    _eventDeactivationParameterProcessor.capturedParameters,
    parameters,
    "AppEvents instance should submit the parameters to event deactivation parameters processor."
  );
}

- (void)testInstanceLogEventProcessParametersWithRestrictiveDataFilterParameterProcessor
{
  NSDictionary<NSString *, id> *parameters = @{@"key" : @"value"};
  [FBSDKAppEvents.singleton instanceLogEvent:_mockEventName
                                  valueToSum:@(_mockPurchaseAmount)
                                  parameters:parameters
                          isImplicitlyLogged:NO
                                 accessToken:nil];
  XCTAssertEqualObjects(
    _restrictiveDataFilterParameterProcessor.capturedEventName,
    _mockEventName,
    "AppEvents instance should submit the event name to the restrictive data filter parameters processor."
  );
  XCTAssertEqualObjects(
    _restrictiveDataFilterParameterProcessor.capturedParameters,
    parameters,
    "AppEvents instance should submit the parameters to the restrictive data filter parameters processor."
  );
}

#pragma mark  Test for log push notification

- (void)testLogPushNotificationOpen
{
  NSString *eventName = @"fb_mobile_push_opened";
  // with action and campaign
  NSDictionary<NSString *, NSString *> *expectedParams1 = @{
    @"fb_push_action" : @"testAction",
    @"fb_push_campaign" : @"testCampaign",
  };
  OCMExpect([self.appEventsMock logEvent:eventName parameters:expectedParams1]);
  [FBSDKAppEvents logPushNotificationOpen:_mockPayload action:@"testAction"];
  OCMVerifyAll(self.appEventsMock);

  // empty action
  NSDictionary<NSString *, NSString *> *expectedParams2 = @{
    @"fb_push_campaign" : @"testCampaign",
  };
  OCMExpect([self.appEventsMock logEvent:eventName parameters:expectedParams2]);
  [FBSDKAppEvents logPushNotificationOpen:_mockPayload];
  OCMVerifyAll(self.appEventsMock);

  // empty payload
  OCMReject([self.appEventsMock logEvent:eventName parameters:[OCMArg any]]);
  [FBSDKAppEvents logPushNotificationOpen:@{}];

  // empty campaign
  NSDictionary<NSString *, id> *mockPayload = @{@"fb_push_payload" : @{@"campaign" : @""}};
  OCMReject([self.appEventsMock logEvent:eventName parameters:[OCMArg any]]);
  [FBSDKAppEvents logPushNotificationOpen:mockPayload];

  XCTAssertEqual(
    TestLogger.capturedLoggingBehavior,
    FBSDKLoggingBehaviorDeveloperErrors,
    "A log entry of LoggingBehaviorDeveloperErrors should be posted if logPushNotificationOpen is fed with empty campagin"
  );
}

- (void)testSetFlushBehavior
{
  [FBSDKAppEvents setFlushBehavior:FBSDKAppEventsFlushBehaviorAuto];
  XCTAssertEqual(FBSDKAppEventsFlushBehaviorAuto, FBSDKAppEvents.flushBehavior);

  [FBSDKAppEvents setFlushBehavior:FBSDKAppEventsFlushBehaviorExplicitOnly];
  XCTAssertEqual(FBSDKAppEventsFlushBehaviorExplicitOnly, FBSDKAppEvents.flushBehavior);
}

- (void)testCheckPersistedEventsCalledWhenLogEvent
{
  OCMStub([self.appEventsMock flushBehavior]).andReturn(FBSDKAppEventsFlushReasonEagerlyFlushingEvent);

  [FBSDKAppEvents logEvent:FBSDKAppEventNamePurchased valueToSum:@(_mockPurchaseAmount) parameters:@{} accessToken:nil];

  OCMVerifyAll(self.appEventsMock);
  XCTAssertTrue(
    _appEventsStateStore.retrievePersistedAppEventStatesWasCalled,
    "Should retrieve persisted states when logEvent was called and flush behavior was FlushReasonEagerlyFlushingEvent"
  );
}

- (void)testRequestForCustomAudienceThirdPartyIDWithTrackingDisallowed
{
  _settings.advertisingTrackingStatus = FBSDKAdvertisingTrackingDisallowed;

  XCTAssertNil(
    [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:SampleAccessTokens.validToken],
    "Should not create a request for third party id if tracking is disallowed even if there is a current access token"
  );
  XCTAssertNil(
    [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:nil],
    "Should not create a request for third party id if tracking is disallowed"
  );
}

- (void)testRequestForCustomAudienceThirdPartyIDWithLimitedEventAndDataUsage
{
  _settings.stubbedLimitEventAndDataUsage = YES;
  _settings.advertisingTrackingStatus = FBSDKAdvertisingTrackingAllowed;

  XCTAssertNil(
    [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:SampleAccessTokens.validToken],
    "Should not create a request for third party id if event and data usage is limited even if there is a current access token"
  );
  XCTAssertNil(
    [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:nil],
    "Should not create a request for third party id if event and data usage is limited"
  );
}

- (void)testRequestForCustomAudienceThirdPartyIDWithoutAccessTokenWithoutAdvertiserID
{
  _settings.stubbedLimitEventAndDataUsage = NO;
  _settings.advertisingTrackingStatus = FBSDKAdvertisingTrackingAllowed;
  [self stubAppEventsUtilityAdvertiserIDWith:nil];

  XCTAssertNil(
    [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:nil],
    "Should not create a request for third party id if there is no access token or advertiser id"
  );
}

- (void)testRequestForCustomAudienceThirdPartyIDWithoutAccessTokenWithAdvertiserID
{
  NSString *advertiserID = @"abc123";
  _settings.stubbedLimitEventAndDataUsage = NO;
  _settings.advertisingTrackingStatus = FBSDKAdvertisingTrackingAllowed;
  [self stubAppEventsUtilityAdvertiserIDWith:advertiserID];

  [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:nil];
  XCTAssertEqualObjects(
    _graphRequestFactory.capturedParameters,
    @{ @"udid" : advertiserID },
    "Should include the udid in the request when there is no access token available"
  );
}

- (void)testRequestForCustomAudienceThirdPartyIDWithAccessTokenWithoutAdvertiserID
{
  FBSDKAccessToken *token = SampleAccessTokens.validToken;
  _settings.stubbedLimitEventAndDataUsage = NO;
  _settings.advertisingTrackingStatus = FBSDKAdvertisingTrackingAllowed;
  [self stubAppEventsUtilityAdvertiserIDWith:nil];
  [self stubAppEventsUtilityTokenStringToUseForTokenWith:token.tokenString];

  [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:token];
  XCTAssertEqualObjects(
    _graphRequestFactory.capturedTokenString,
    token.tokenString,
    "Should include the access token in the request when there is one available"
  );
  XCTAssertNil(
    _graphRequestFactory.capturedParameters[@"udid"],
    "Should not include the udid in the request when there is none available"
  );
}

- (void)testRequestForCustomAudienceThirdPartyIDWithAccessTokenWithAdvertiserID
{
  NSString *expectedGraphPath = [NSString stringWithFormat:@"%@/custom_audience_third_party_id", _mockAppID];

  FBSDKAccessToken *token = SampleAccessTokens.validToken;
  NSString *advertiserID = @"abc123";
  _settings.stubbedLimitEventAndDataUsage = NO;
  _settings.advertisingTrackingStatus = FBSDKAdvertisingTrackingAllowed;
  [self stubAppEventsUtilityTokenStringToUseForTokenWith:token.tokenString];
  [self stubAppEventsUtilityAdvertiserIDWith:advertiserID];

  [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:token];

  XCTAssertEqualObjects(
    _graphRequestFactory.capturedTokenString,
    token.tokenString,
    "Should include the access token in the request when there is one available"
  );
  XCTAssertNil(
    _graphRequestFactory.capturedParameters[@"udid"],
    "Should not include the udid in the request when there is an access token available"
  );
  XCTAssertEqualObjects(
    _graphRequestFactory.capturedGraphPath,
    expectedGraphPath,
    "Should use the expected graph path for the request"
  );
  XCTAssertEqual(
    _graphRequestFactory.capturedHttpMethod,
    FBSDKHTTPMethodGET,
    "Should use the expected http method for the request"
  );
  XCTAssertEqual(
    _graphRequestFactory.capturedFlags,
    FBSDKGraphRequestFlagDoNotInvalidateTokenOnError | FBSDKGraphRequestFlagDisableErrorRecovery,
    "Should use the expected flags for the request"
  );
}

- (void)testPublishInstall
{
  [self stubAppID:self.appID];
  OCMExpect([self.appEventsMock fetchServerConfiguration:[OCMArg any]]);

  [self.appEventsMock publishInstall];

  OCMVerifyAll(self.appEventsMock);
}

#pragma mark  Tests for Kill Switch

- (void)testAppEventsKillSwitchDisabled
{
  [TestGateKeeperManager setGateKeeperValueWithKey:@"app_events_killswitch" value:NO];

  OCMExpect([self.appEventStatesMock addEvent:[OCMArg any] isImplicit:NO]);

  [self.appEventsMock instanceLogEvent:_mockEventName
                            valueToSum:@(_mockPurchaseAmount)
                            parameters:nil
                    isImplicitlyLogged:NO
                           accessToken:nil];

  [self.appEventStatesMock verify];
}

- (void)testAppEventsKillSwitchEnabled
{
  [TestGateKeeperManager setGateKeeperValueWithKey:@"app_events_killswitch" value:YES];

  OCMReject([self.appEventStatesMock addEvent:[OCMArg any] isImplicit:NO]);

  [self.appEventsMock instanceLogEvent:_mockEventName
                            valueToSum:@(_mockPurchaseAmount)
                            parameters:nil
                    isImplicitlyLogged:NO
                           accessToken:nil];

  [TestGateKeeperManager setGateKeeperValueWithKey:@"app_events_killswitch" value:NO];
}

#pragma mark  Tests for log event

- (void)testLogEventWithValueToSum
{
  OCMExpect(
    [self.appEventsMock logEvent:_mockEventName
                      valueToSum:_mockPurchaseAmount
                      parameters:@{}]
  ).andForwardToRealObject();
  OCMExpect(
    [self.appEventsMock logEvent:_mockEventName
                      valueToSum:@(_mockPurchaseAmount)
                      parameters:@{}
                     accessToken:nil]
  ).andForwardToRealObject();

  [FBSDKAppEvents logEvent:_mockEventName valueToSum:_mockPurchaseAmount];

  OCMVerifyAll(self.appEventsMock);
}

- (void)testLogInternalEvents
{
  OCMExpect(
    [self.appEventsMock logInternalEvent:_mockEventName
                              parameters:@{}
                      isImplicitlyLogged:NO]
  ).andForwardToRealObject();
  OCMExpect(
    [self.appEventsMock logInternalEvent:_mockEventName
                              valueToSum:nil
                              parameters:@{}
                      isImplicitlyLogged:NO
                             accessToken:nil]
  ).andForwardToRealObject();

  [FBSDKAppEvents logInternalEvent:_mockEventName isImplicitlyLogged:NO];

  OCMVerifyAll(self.appEventsMock);
}

- (void)testLogInternalEventsWithValue
{
  OCMExpect(
    [self.appEventsMock logInternalEvent:_mockEventName
                              valueToSum:_mockPurchaseAmount
                              parameters:@{}
                      isImplicitlyLogged:NO]
  ).andForwardToRealObject();
  OCMExpect(
    [self.appEventsMock logInternalEvent:_mockEventName
                              valueToSum:@(_mockPurchaseAmount)
                              parameters:@{}
                      isImplicitlyLogged:NO
                             accessToken:nil]
  ).andForwardToRealObject();

  [FBSDKAppEvents logInternalEvent:_mockEventName valueToSum:_mockPurchaseAmount isImplicitlyLogged:NO];

  OCMVerifyAll(self.appEventsMock);
}

- (void)testLogInternalEventWithAccessToken
{
  id mockAccessToken = [OCMockObject niceMockForClass:[FBSDKAccessToken class]];
  OCMExpect(
    [self.appEventsMock logInternalEvent:_mockEventName
                              valueToSum:nil
                              parameters:@{}
                      isImplicitlyLogged:NO
                             accessToken:mockAccessToken]
  ).andForwardToRealObject();
  [FBSDKAppEvents logInternalEvent:_mockEventName parameters:@{} isImplicitlyLogged:NO accessToken:mockAccessToken];
  OCMVerifyAll(self.appEventsMock);

  [mockAccessToken stopMocking];
  mockAccessToken = nil;
}

- (void)testInstanceLogEventWhenAutoLogAppEventsDisabled
{
  _settings.stubbedIsAutoLogAppEventsEnabled = NO;
  OCMReject(
    [self.appEventsMock instanceLogEvent:_mockEventName
                              valueToSum:@(_mockPurchaseAmount)
                              parameters:@{}
                      isImplicitlyLogged:NO
                             accessToken:nil]
  );

  [FBSDKAppEvents logInternalEvent:_mockEventName valueToSum:_mockPurchaseAmount isImplicitlyLogged:NO];
}

- (void)testInstanceLogEventWhenAutoLogAppEventsEnabled
{
  OCMExpect(
    [self.appEventsMock instanceLogEvent:_mockEventName
                              valueToSum:@(_mockPurchaseAmount)
                              parameters:@{}
                      isImplicitlyLogged:NO
                             accessToken:nil]
  ).andForwardToRealObject();

  [FBSDKAppEvents logInternalEvent:_mockEventName valueToSum:_mockPurchaseAmount isImplicitlyLogged:NO];

  OCMVerifyAll(self.appEventsMock);
}

- (void)testLogImplicitEvent
{
  OCMExpect(
    [self.appEventsMock instanceLogEvent:_mockEventName
                              valueToSum:@(_mockPurchaseAmount)
                              parameters:@{}
                      isImplicitlyLogged:YES
                             accessToken:nil]
  );

  [FBSDKAppEvents logImplicitEvent:_mockEventName valueToSum:@(_mockPurchaseAmount) parameters:@{} accessToken:nil];

  OCMVerifyAll(self.appEventsMock);
}

#pragma mark Test for Server Configuration

- (void)testFetchServerConfiguration
{
  FBSDKAppEventsConfiguration *configuration = [[FBSDKAppEventsConfiguration alloc] initWithJSON:@{}];
  TestAppEventsConfigurationProvider.stubbedConfiguration = configuration;

  __block BOOL didRunCallback = NO;
  [[FBSDKAppEvents singleton] fetchServerConfiguration:^void (void) {
    didRunCallback = YES;
  }];
  XCTAssertNotNil(
    TestAppEventsConfigurationProvider.capturedBlock,
    "The expected block should be captured by the AppEventsConfiguration provider"
  );
  TestAppEventsConfigurationProvider.capturedBlock();
  XCTAssertNotNil(
    TestServerConfigurationProvider.capturedCompletionBlock,
    "The expected block should be captured by the ServerConfiguration provider"
  );
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  XCTAssertTrue(
    didRunCallback,
    "fetchServerConfiguration should call the callback block"
  );
}

- (void)testFetchingConfigurationIncludingCertainFeatures
{
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);

  XCTAssertTrue(
    [_featureManager capturedFeaturesContains:FBSDKFeatureATELogging],
    "fetchConfiguration should check if the ATELogging feature is enabled"
  );
  XCTAssertTrue(
    [_featureManager capturedFeaturesContains:FBSDKFeatureCodelessEvents],
    "fetchConfiguration should check if CodelessEvents feature is enabled"
  );
}

- (void)testFetchingConfigurationIncludingEventDeactivation
{
  [FBSDKAppEvents.singleton fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  XCTAssertTrue(
    [_featureManager capturedFeaturesContains:FBSDKFeatureEventDeactivation],
    "Fetching a configuration should check if the EventDeactivation feature is enabled"
  );
}

- (void)testFetchingConfigurationEnablingEventDeactivationParameterProcessorIfEventDeactivationEnabled
{
  [FBSDKAppEvents.singleton fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  [_featureManager completeCheckForFeature:FBSDKFeatureEventDeactivation with:YES];
  XCTAssertTrue(
    _eventDeactivationParameterProcessor.enableWasCalled,
    "Fetching a configuration should enable event deactivation parameters processor if event deactivation feature is enabled"
  );
}

- (void)testFetchingConfigurationIncludingRestrictiveDataFiltering
{
  [FBSDKAppEvents.singleton fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  XCTAssertTrue(
    [_featureManager capturedFeaturesContains:FBSDKFeatureRestrictiveDataFiltering],
    "Fetching a configuration should check if the RestrictiveDataFiltering feature is enabled"
  );
}

- (void)testFetchingConfigurationEnablingRestrictiveDataFilterParameterProcessorIfRestrictiveDataFilteringEnabled
{
  [FBSDKAppEvents.singleton fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  [_featureManager completeCheckForFeature:FBSDKFeatureRestrictiveDataFiltering with:YES];
  XCTAssertTrue(
    _restrictiveDataFilterParameterProcessor.enableWasCalled,
    "Fetching a configuration should enable restrictive data filter parameters processor if event deactivation feature is enabled"
  );
}

- (void)testFetchingConfigurationIncludingAAM
{
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  XCTAssertTrue(
    [_featureManager capturedFeaturesContains:FBSDKFeatureAAM],
    "Fetch a configuration should check if the AAM feature is enabled"
  );
}

- (void)testFetchingConfigurationEnablingMetadataIndexigIfAAMEnabled
{
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  [_featureManager completeCheckForFeature:FBSDKFeatureAAM with:YES];
  XCTAssertTrue(
    _metadataIndexer.enableWasCalled,
    "Fetching a configuration should enable metadata indexer if AAM feature is enabled"
  );
}

- (void)testFetchingConfigurationStartsPaymentObservingIfConfigurationAllowed
{
  _settings.stubbedIsAutoLogAppEventsEnabled = YES;
  FBSDKServerConfiguration *serverConfiguration = [FBSDKServerConfigurationFixtures configWithDictionary:@{@"implicitPurchaseLoggingEnabled" : @YES}];
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(serverConfiguration, nil);
  XCTAssertTrue(
    _paymentObserver.didStartObservingTransactions,
    "fetchConfiguration should start payment observing if the configuration allows it"
  );
  XCTAssertFalse(
    _paymentObserver.didStopObservingTransactions,
    "fetchConfiguration shouldn't stop payment observing if the configuration allows it"
  );
}

- (void)testFetchingConfigurationStopsPaymentObservingIfConfigurationDisallowed
{
  _settings.stubbedIsAutoLogAppEventsEnabled = YES;
  FBSDKServerConfiguration *serverConfiguration = [FBSDKServerConfigurationFixtures configWithDictionary:@{@"implicitPurchaseLoggingEnabled" : @NO}];
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(serverConfiguration, nil);
  XCTAssertFalse(
    _paymentObserver.didStartObservingTransactions,
    "Fetching a configuration shouldn't start payment observing if the configuration disallows it"
  );
  XCTAssertTrue(
    _paymentObserver.didStopObservingTransactions,
    "Fetching a configuration should stop payment observing if the configuration disallows it"
  );
}

- (void)testFetchingConfigurationStopPaymentObservingIfAutoLogAppEventsDisabled
{
  _settings.stubbedIsAutoLogAppEventsEnabled = NO;
  FBSDKServerConfiguration *serverConfiguration = [FBSDKServerConfigurationFixtures configWithDictionary:@{@"implicitPurchaseLoggingEnabled" : @YES}];
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(serverConfiguration, nil);
  XCTAssertFalse(
    _paymentObserver.didStartObservingTransactions,
    "Fetching a configuration shouldn't start payment observing if auto log app events is disabled"
  );
  XCTAssertTrue(
    _paymentObserver.didStopObservingTransactions,
    "Fetching a configuration should stop payment observing if auto log app events is disabled"
  );
}

- (void)testFetchingConfigurationIncludingSKAdNetworkIfSKAdNetworkReportEnabled
{
  _settings.stubbedIsSKAdNetworkReportEnabled = YES;
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  XCTAssertTrue(
    [_featureManager capturedFeaturesContains:FBSDKFeatureSKAdNetwork],
    "fetchConfiguration should check if the SKAdNetwork feature is enabled when SKAdNetworkReport is enabled"
  );
}

- (void)testFetchingConfigurationNotIncludingSKAdNetworkIfSKAdNetworkReportDisabled
{
  _settings.stubbedIsSKAdNetworkReportEnabled = NO;
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  XCTAssertFalse(
    [_featureManager capturedFeaturesContains:FBSDKFeatureSKAdNetwork],
    "fetchConfiguration should NOT check if the SKAdNetwork feature is disabled when SKAdNetworkReport is disabled"
  );
}

- (void)testFetchingConfigurationIncludingAEM
{
  if (@available(iOS 14.0, *)) {
    FBSDKAEMReporter.isEnabled = NO;
    [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
    TestAppEventsConfigurationProvider.capturedBlock();
    TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
    XCTAssertTrue(
      [_featureManager capturedFeaturesContains:FBSDKFeatureAEM],
      "Fetching a configuration should check if the AEM feature is enabled"
    );
  }
}

- (void)testFetchingConfigurationIncludingPrivacyProtection
{
  [[FBSDKAppEvents singleton] fetchServerConfiguration:nil];
  TestAppEventsConfigurationProvider.capturedBlock();
  TestServerConfigurationProvider.capturedCompletionBlock(nil, nil);
  XCTAssertTrue(
    [_featureManager capturedFeaturesContains:FBSDKFeaturePrivacyProtection],
    "Fetching a configuration should check if the PrivacyProtection feature is enabled"
  );
  [_featureManager completeCheckForFeature:FBSDKFeaturePrivacyProtection
                                      with:YES];
  XCTAssertTrue(
    _onDeviceMLModelManager.isEnabled,
    "Fetching a configuration should enable event processing if PrivacyProtection feature is enabled"
  );
}

#pragma mark Test for Singleton Values

- (void)testCanLogEventValues
{
  [FBSDKAppEvents reset];
  XCTAssertFalse([FBSDKAppEvents canLogEvents], "The default value of canLogEvents should be NO");
  [FBSDKAppEvents setCanLogEvents];
  XCTAssertTrue([FBSDKAppEvents canLogEvents], "canLogEvents should now have a value of YES");
}

- (void)testApplicationStateValues
{
  XCTAssertEqual([FBSDKAppEvents.singleton applicationState], UIApplicationStateInactive, "The default value of applicationState should be UIApplicationStateInactive");
  [FBSDKAppEvents.singleton setApplicationState:UIApplicationStateBackground];
  XCTAssertEqual([FBSDKAppEvents.singleton applicationState], UIApplicationStateBackground, "The value of applicationState after calling setApplicationState should be UIApplicationStateBackground");
}

@end
