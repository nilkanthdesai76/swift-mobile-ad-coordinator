import Foundation

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// Unified consent state representing GDPR/UMP consent and App Tracking Transparency.
public enum TrackingConsentStatus: String, Sendable, Codable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case notSupported
}

/// Orchestrates user privacy compliance across Apple App Tracking Transparency (ATT) and GDPR consent frameworks.
public actor ATTConsentCoordinator {
    public private(set) var currentStatus: TrackingConsentStatus = .notDetermined

    public init() {}

    /// Evaluates current ATT authorization status without prompting the user.
    public func checkCurrentStatus() -> TrackingConsentStatus {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14.5, macOS 11.0, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .notDetermined: return .notDetermined
            case .restricted: return .restricted
            case .denied: return .denied
            case .authorized: return .authorized
            @unknown default: return .notDetermined
            }
        } else {
            return .authorized
        }
        #else
        return .notSupported
        #endif
    }

    /// Requests tracking authorization if status is currently `.notDetermined`.
    /// Executes safely on the main queue after the application window has settled.
    public func requestTrackingAuthorization() async -> TrackingConsentStatus {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14.5, macOS 11.0, *) {
            let status = await withCheckedContinuation { continuation in
                Task { @MainActor in
                    ATTrackingManager.requestTrackingAuthorization { rawStatus in
                        let mapped: TrackingConsentStatus
                        switch rawStatus {
                        case .notDetermined: mapped = .notDetermined
                        case .restricted: mapped = .restricted
                        case .denied: mapped = .denied
                        case .authorized: mapped = .authorized
                        @unknown default: mapped = .notDetermined
                        }
                        continuation.resume(returning: mapped)
                    }
                }
            }
            self.currentStatus = status
            return status
        } else {
            self.currentStatus = .authorized
            return .authorized
        }
        #else
        self.currentStatus = .notSupported
        return .notSupported
        #endif
    }
}
