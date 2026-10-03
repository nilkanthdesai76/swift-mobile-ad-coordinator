import Foundation

#if canImport(UIKit)
import UIKit
public typealias ViewControllerType = UIViewController
#else
public class ViewControllerType: @unchecked Sendable {}
#endif

/// Ad format placements supported by the coordinator.
public enum AdPlacement: String, Sendable, Codable, Hashable {
    case splashAppOpen = "splash_app_open"
    case resumeAppOpen = "resume_app_open"
    case interstitial = "interstitial"
    case rewarded = "rewarded"
    case banner = "banner"
}

/// Result returned by ad loading operations.
public enum AdLoadResult: Sendable, Equatable {
    case success
    case failure(String)
}

/// Protocol defining the interface for ad network SDK adapters (e.g. Google AdMob, AppLovin MAX).
public protocol AdProvider: Sendable {
    /// Loads an ad for the specified placement on demand.
    func loadAd(placement: AdPlacement) async -> AdLoadResult
    /// Checks if a valid ad is ready to present for the given placement.
    func isAdReady(placement: AdPlacement) -> Bool
    /// Presents the ad from the specified view controller.
    @MainActor
    func presentAd(placement: AdPlacement, from viewController: ViewControllerType?, onDismiss: @escaping @Sendable () -> Void) -> Bool
}

/// In-memory mock ad provider for SwiftUI previews, UI testing, and unit tests.
public final class MockAdProvider: AdProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var readyPlacements: Set<AdPlacement> = []
    private var simulatedLoadSuccess: Bool = true
    public private(set) var impressionCount: [AdPlacement: Int] = [:]

    public init(initiallyReady: Set<AdPlacement> = [.interstitial, .resumeAppOpen, .splashAppOpen]) {
        self.readyPlacements = initiallyReady
    }

    private func withLock<T>(_ block: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }

    public func setSimulatedLoadSuccess(_ success: Bool) {
        withLock { simulatedLoadSuccess = success }
    }

    public func setAdReady(_ placement: AdPlacement, ready: Bool) {
        withLock {
            if ready {
                readyPlacements.insert(placement)
            } else {
                readyPlacements.remove(placement)
            }
        }
    }

    public func loadAd(placement: AdPlacement) async -> AdLoadResult {
        let success = withLock {
            if simulatedLoadSuccess {
                readyPlacements.insert(placement)
                return true
            }
            return false
        }

        if success {
            return .success
        } else {
            return .failure("Simulated network timeout")
        }
    }

    public func isAdReady(placement: AdPlacement) -> Bool {
        withLock { readyPlacements.contains(placement) }
    }

    @MainActor
    public func presentAd(placement: AdPlacement, from viewController: ViewControllerType?, onDismiss: @escaping @Sendable () -> Void) -> Bool {
        let wasReady = withLock { () -> Bool in
            guard readyPlacements.contains(placement) else { return false }
            readyPlacements.remove(placement)
            impressionCount[placement, default: 0] += 1
            return true
        }

        guard wasReady else {
            onDismiss()
            return false
        }

        onDismiss()
        return true
    }
}
