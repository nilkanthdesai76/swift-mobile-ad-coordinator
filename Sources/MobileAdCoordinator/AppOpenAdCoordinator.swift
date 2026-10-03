import Foundation

/// Reasons why App Open ads should be suppressed during lifecycle transitions.
public enum AppOpenSuppressionReason: Hashable, Sendable {
    case paywallActive
    case onboardingActive
    case modalPresentationActive
    case shareSheetActive
    case custom(String)
}

/// Coordinates App Open ad presentation on cold start and background-to-foreground resumes.
public actor AppOpenAdCoordinator {
    private var activeSuppressions: Set<AppOpenSuppressionReason> = []
    private var lastAppOpenDismissTime: Date?
    private let resumeCooldownSeconds: TimeInterval

    public init(resumeCooldownSeconds: TimeInterval = 120.0) {
        self.resumeCooldownSeconds = max(0, resumeCooldownSeconds)
    }

    /// Adds a suppression reason to prevent App Open ads from presenting.
    public func addSuppression(_ reason: AppOpenSuppressionReason) {
        activeSuppressions.insert(reason)
    }

    /// Removes a suppression reason when the corresponding view or flow dismisses.
    public func removeSuppression(_ reason: AppOpenSuppressionReason) {
        activeSuppressions.remove(reason)
    }

    /// Clears all suppression flags.
    public func clearSuppressions() {
        activeSuppressions.removeAll()
    }

    /// Determines if an App Open ad can be presented safely.
    public func shouldShowAppOpenAd() -> Bool {
        guard activeSuppressions.isEmpty else {
            return false
        }

        if let lastTime = lastAppOpenDismissTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            guard elapsed >= resumeCooldownSeconds else {
                return false
            }
        }

        return true
    }

    /// Records that an App Open ad was dismissed.
    public func recordAppOpenDismissed() {
        lastAppOpenDismissTime = Date()
    }

    /// Active suppression count.
    public var suppressionCount: Int {
        activeSuppressions.count
    }
}
