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

import UIKit

@objcMembers
class TestAppEvents: TestEventLogger,
                     AppEventsConfiguring,
                     ApplicationActivating,
                     ApplicationLifecycleObserving,
                     ApplicationStateSetting {

  var wasActivateAppCalled = false
  // swiftlint:disable:next identifier_name
  var wasStartObservingApplicationLifecycleNotificationsCalled = false
  var capturedApplicationState: UIApplication.State = .inactive

  func activateApp() {
    wasActivateAppCalled = true
  }

  func startObservingApplicationLifecycleNotifications() {
    wasStartObservingApplicationLifecycleNotificationsCalled = true
  }

  func setApplicationState(_ state: UIApplication.State) {
    capturedApplicationState = state
  }

  // swiftlint:disable identifier_name
  var capturedConfigureGateKeeperManager: GateKeeperManaging.Type?
  var capturedConfigureAppEventsConfigurationProvider: AppEventsConfigurationProviding.Type?
  var capturedConfigureServerConfigurationProvider: ServerConfigurationProviding.Type?
  var capturedConfigureGraphRequestProvider: GraphRequestProviding?
  var capturedConfigureFeatureChecker: FeatureChecking?
  var capturedConfigureStore: DataPersisting?
  var capturedConfigureLogger: Logging.Type?
  var capturedConfigureSettings: SettingsProtocol?
  var capturedConfigurePaymentObserver: PaymentObserving?
  var capturedConfigureTimeSpentRecorder: TimeSpentRecording?
  var capturedConfigureAppEventsStateStore: AppEventsStatePersisting?
  var capturedConfigureEventDeactivationParameterProcessor: AppEventsParameterProcessing?
  var capturedConfigureRestrictiveDataFilterParameterProcessor: AppEventsParameterProcessing?
  var capturedConfigureAtePublisherFactory: AtePublisherCreating?

  // swiftlint:disable:next function_parameter_count
  func configure(
    withGateKeeperManager gateKeeperManager: GateKeeperManaging.Type,
    appEventsConfigurationProvider: AppEventsConfigurationProviding.Type,
    serverConfigurationProvider: ServerConfigurationProviding.Type,
    graphRequestProvider provider: GraphRequestProviding,
    featureChecker: FeatureChecking,
    store: DataPersisting,
    logger: Logging.Type,
    settings: SettingsProtocol,
    paymentObserver: PaymentObserving,
    timeSpentRecorder: TimeSpentRecording,
    appEventsStateStore: AppEventsStatePersisting,
    eventDeactivationParameterProcessor: AppEventsParameterProcessing,
    restrictiveDataFilterParameterProcessor: AppEventsParameterProcessing,
    atePublisherFactory: AtePublisherCreating
  ) {
    capturedConfigureGateKeeperManager = gateKeeperManager
    capturedConfigureAppEventsConfigurationProvider = appEventsConfigurationProvider
    capturedConfigureServerConfigurationProvider = serverConfigurationProvider
    capturedConfigureGraphRequestProvider = provider
    capturedConfigureFeatureChecker = featureChecker
    capturedConfigureStore = store
    capturedConfigureLogger = logger
    capturedConfigureSettings = settings
    capturedConfigurePaymentObserver = paymentObserver
    capturedConfigureTimeSpentRecorder = timeSpentRecorder
    capturedConfigureAppEventsStateStore = appEventsStateStore
    capturedConfigureEventDeactivationParameterProcessor = eventDeactivationParameterProcessor
    capturedConfigureRestrictiveDataFilterParameterProcessor = restrictiveDataFilterParameterProcessor
    capturedConfigureAtePublisherFactory = atePublisherFactory
  }
}
