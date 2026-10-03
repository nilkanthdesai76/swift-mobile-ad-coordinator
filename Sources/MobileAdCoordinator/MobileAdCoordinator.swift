import Foundation

/// Central configuration defining intervals, timeouts, and feature toggles for the ad system.
public struct AdCoordinatorConfig: Sendable {
    public var interstitialActionInterval: Int
    public var interstitialGapSeconds: TimeInterval
    public var appOpenCooldownSeconds: TimeInterval
    public var bannerEnabled: Bool
    public var interstitialEnabled: Bool
    public var appOpenEnabled: Bool

    public init(
        interstitialActionInterval: Int = 3,
        interstitialGapSeconds: TimeInterval = 60.0,
        appOpenCooldownSeconds: TimeInterval = 120.0,
        bannerEnabled: Bool = true,
        interstitialEnabled: Bool = true,
        appOpenEnabled: Bool = true
    ) {
        self.interstitialActionInterval = interstitialActionInterval
        self.interstitialGapSeconds = interstitialGapSeconds
        self.appOpenCooldownSeconds = appOpenCooldownSeconds
        self.bannerEnabled = bannerEnabled
        self.interstitialEnabled = interstitialEnabled
        self.appOpenEnabled = appOpenEnabled
    }
}

/// The main entry point and orchestrator for all advertising workflows in the application.
public final class MobileAdCoordinator: @unchecked Sendable {
    public static let shared = MobileAdCoordinator()

    private let lock = NSLock()
    private var provider: AdProvider
    private var config: AdCoordinatorConfig
    private var isPremiumCheck: @Sendable () -> Bool

    public let featureTracker: FeatureUsageTracker
    public let appOpenCoordinator: AppOpenAdCoordinator
    public let consentCoordinator: ATTConsentCoordinator

    public init(
        provider: AdProvider = MockAdProvider(),
        config: AdCoordinatorConfig = AdCoordinatorConfig(),
        isPremiumCheck: @escaping @Sendable () -> Bool = { false }
    ) {
        self.provider = provider
        self.config = config
        self.isPremiumCheck = isPremiumCheck
        self.featureTracker = FeatureUsageTracker(
            actionInterval: config.interstitialActionInterval,
            minimumGapSeconds: config.interstitialGapSeconds
        )
        self.appOpenCoordinator = AppOpenAdCoordinator(
            resumeCooldownSeconds: config.appOpenCooldownSeconds
        )
        self.consentCoordinator = ATTConsentCoordinator()
    }

    /// Configures the coordinator with a customized ad provider, configuration, and entitlement checker.
    public func configure(
        provider: AdProvider,
        config: AdCoordinatorConfig = AdCoordinatorConfig(),
        isPremiumCheck: @escaping @Sendable () -> Bool = { false }
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.provider = provider
        self.config = config
        self.isPremiumCheck = isPremiumCheck
    }

    private func withLock<T>(_ block: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }

    /// Evaluates if ads should be displayed for the active user session.
    public var isPremiumUser: Bool {
        withLock { isPremiumCheck() }
    }

    /// Records an arbitrary user action (e.g. document export, filter apply, save button tapped).
    /// Returns true if an interstitial is eligible to trigger.
    public func recordAction() async -> Bool {
        guard !isPremiumUser else { return false }
        let enabled = withLock { config.interstitialEnabled }
        guard enabled else { return false }

        return await featureTracker.recordActionAndCheckShouldShow()
    }

    /// Presents an interstitial ad on-demand if conditions are met or if forced by paywall dismissal.
    @MainActor
    public func showInterstitial(
        from viewController: ViewControllerType? = nil,
        forced: Bool = false,
        onDismiss: @escaping @Sendable () -> Void
    ) async -> Bool {
        guard !isPremiumUser else {
            onDismiss()
            return false
        }

        let (enabled, activeProvider) = withLock { (config.interstitialEnabled, provider) }

        guard enabled else {
            onDismiss()
            return false
        }

        if !forced {
            let shouldShow = await featureTracker.shouldShowInterstitial()
            guard shouldShow else {
                onDismiss()
                return false
            }
        }

        // Check if ad is cached or load on-demand
        if !activeProvider.isAdReady(placement: .interstitial) {
            let result = await activeProvider.loadAd(placement: .interstitial)
            guard case .success = result else {
                onDismiss()
                return false
            }
        }

        let presented = activeProvider.presentAd(placement: .interstitial, from: viewController) { [weak self] in
            Task { [weak self] in
                await self?.featureTracker.recordInterstitialDismissed()
            }
            onDismiss()
        }

        return presented
    }

    /// Presents an App Open ad on cold start or background resume if eligible.
    @MainActor
    public func showAppOpenAd(
        placement: AdPlacement = .resumeAppOpen,
        from viewController: ViewControllerType? = nil,
        onDismiss: @escaping @Sendable () -> Void
    ) async -> Bool {
        guard !isPremiumUser else {
            onDismiss()
            return false
        }

        let (enabled, activeProvider) = withLock { (config.appOpenEnabled, provider) }

        guard enabled else {
            onDismiss()
            return false
        }

        let shouldShow = await appOpenCoordinator.shouldShowAppOpenAd()
        guard shouldShow else {
            onDismiss()
            return false
        }

        if !activeProvider.isAdReady(placement: placement) {
            let result = await activeProvider.loadAd(placement: placement)
            guard case .success = result else {
                onDismiss()
                return false
            }
        }

        let presented = activeProvider.presentAd(placement: placement, from: viewController) { [weak self] in
            Task { [weak self] in
                await self?.appOpenCoordinator.recordAppOpenDismissed()
            }
            onDismiss()
        }

        return presented
    }
}
