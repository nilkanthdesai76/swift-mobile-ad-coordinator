import XCTest
@testable import MobileAdCoordinator

final class MobileAdCoordinatorTests: XCTestCase {

    func testMockAdProviderLifecycle() async {
        let provider = MockAdProvider(initiallyReady: [])
        XCTAssertFalse(provider.isAdReady(placement: .interstitial))

        let result = await provider.loadAd(placement: .interstitial)
        XCTAssertEqual(result, .success)
        XCTAssertTrue(provider.isAdReady(placement: .interstitial))

        let expectation = expectation(description: "Ad dismissed")
        let presented = await MainActor.run {
            provider.presentAd(placement: .interstitial, from: nil) {
                expectation.fulfill()
            }
        }

        XCTAssertTrue(presented)
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(provider.impressionCount[.interstitial], 1)
        XCTAssertFalse(provider.isAdReady(placement: .interstitial))
    }

    func testFeatureUsageTrackerActionInterval() async {
        let tracker = FeatureUsageTracker(actionInterval: 3, minimumGapSeconds: 0)

        let action1 = await tracker.recordActionAndCheckShouldShow()
        XCTAssertFalse(action1, "Action 1 should not trigger ad")

        let action2 = await tracker.recordActionAndCheckShouldShow()
        XCTAssertFalse(action2, "Action 2 should not trigger ad")

        let action3 = await tracker.recordActionAndCheckShouldShow()
        XCTAssertTrue(action3, "Action 3 must trigger ad")

        await tracker.recordInterstitialDismissed()
        let countAfterDismiss = await tracker.currentActionCount
        XCTAssertEqual(countAfterDismiss, 0, "Action count must reset after dismiss")
    }

    func testFeatureUsageTrackerTimeGap() async {
        let tracker = FeatureUsageTracker(actionInterval: 1, minimumGapSeconds: 60.0)

        let first = await tracker.recordActionAndCheckShouldShow()
        XCTAssertTrue(first)

        await tracker.recordInterstitialDismissed()

        // Immediately perform another action
        let second = await tracker.recordActionAndCheckShouldShow()
        XCTAssertFalse(second, "Must not trigger ad before minimumGapSeconds elapsed")

        let remaining = await tracker.secondsUntilNextAdAllowed
        XCTAssertGreaterThan(remaining, 55.0)
    }

    func testAppOpenAdSuppression() async {
        let coordinator = AppOpenAdCoordinator(resumeCooldownSeconds: 0)
        let initiallyAllowed = await coordinator.shouldShowAppOpenAd()
        XCTAssertTrue(initiallyAllowed)

        await coordinator.addSuppression(.paywallActive)
        let suppressed = await coordinator.shouldShowAppOpenAd()
        XCTAssertFalse(suppressed, "App open ad must be suppressed while paywall is active")

        await coordinator.removeSuppression(.paywallActive)
        let allowedAgain = await coordinator.shouldShowAppOpenAd()
        XCTAssertTrue(allowedAgain, "App open ad must be allowed once suppression is cleared")
    }

    func testMobileAdCoordinatorPremiumBypass() async {
        let provider = MockAdProvider()
        let coordinator = MobileAdCoordinator(
            provider: provider,
            config: AdCoordinatorConfig(interstitialActionInterval: 1, interstitialGapSeconds: 0),
            isPremiumCheck: { true }
        )

        let actionResult = await coordinator.recordAction()
        XCTAssertFalse(actionResult, "Premium users must never trigger ads")

        let expectation = expectation(description: "Bypassed without presenting")
        let presented = await coordinator.showInterstitial(forced: true) {
            expectation.fulfill()
        }

        XCTAssertFalse(presented, "Must not present ad to premium subscriber")
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testForcedInterstitialBypassesActionInterval() async {
        let provider = MockAdProvider()
        let coordinator = MobileAdCoordinator(
            provider: provider,
            config: AdCoordinatorConfig(interstitialActionInterval: 10, interstitialGapSeconds: 0),
            isPremiumCheck: { false }
        )

        let expectation = expectation(description: "Forced interstitial dismissed")
        let presented = await coordinator.showInterstitial(forced: true) {
            expectation.fulfill()
        }

        XCTAssertTrue(presented, "Forced interstitial must present even with 0 actions")
        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
