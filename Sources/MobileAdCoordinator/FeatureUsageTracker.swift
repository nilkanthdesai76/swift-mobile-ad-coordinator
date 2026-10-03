import Foundation

/// Thread-safe tracker that governs frequency capping, action intervals, and time gaps for interstitials.
public actor FeatureUsageTracker {
    private var actionCount: Int = 0
    private var lastAdDismissTime: Date?
    private let actionInterval: Int
    private let minimumGapSeconds: TimeInterval

    public init(actionInterval: Int = 3, minimumGapSeconds: TimeInterval = 60.0) {
        self.actionInterval = max(1, actionInterval)
        self.minimumGapSeconds = max(0, minimumGapSeconds)
    }

    /// Records an action performed by the user and determines if an interstitial should trigger.
    public func recordActionAndCheckShouldShow() -> Bool {
        actionCount += 1
        return shouldShowInterstitial()
    }

    /// Evaluates whether an interstitial meets both the click interval and time gap requirements.
    public func shouldShowInterstitial() -> Bool {
        guard actionCount >= actionInterval else {
            return false
        }

        if let lastTime = lastAdDismissTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            guard elapsed >= minimumGapSeconds else {
                return false
            }
        }

        return true
    }

    /// Records that an interstitial was presented and dismissed, resetting action counter and recording timestamp.
    public func recordInterstitialDismissed() {
        actionCount = 0
        lastAdDismissTime = Date()
    }

    /// Resets the tracker back to clean initial state.
    public func reset() {
        actionCount = 0
        lastAdDismissTime = nil
    }

    /// Current unpresented action count.
    public var currentActionCount: Int {
        actionCount
    }

    /// Time remaining in seconds before the minimum gap condition is satisfied.
    public var secondsUntilNextAdAllowed: TimeInterval {
        guard let lastTime = lastAdDismissTime else { return 0 }
        let elapsed = Date().timeIntervalSince(lastTime)
        return max(0, minimumGapSeconds - elapsed)
    }
}
