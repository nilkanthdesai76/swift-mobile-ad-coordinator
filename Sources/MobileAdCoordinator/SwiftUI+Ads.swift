import SwiftUI

public struct AdLoadingOverlayModifier: ViewModifier {
    public let isPresented: Bool
    public let message: LocalizedStringKey

    public init(isPresented: Bool, message: LocalizedStringKey = "Loading advertisement...") {
        self.isPresented = isPresented
        self.message = message
    }

    public func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.15).opacity(0.95))
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPresented)
    }
}

public struct AppOpenSuppressionModifier: ViewModifier {
    public let isSuppressed: Bool
    public let reason: AppOpenSuppressionReason
    public let coordinator: MobileAdCoordinator

    public init(isSuppressed: Bool, reason: AppOpenSuppressionReason, coordinator: MobileAdCoordinator = .shared) {
        self.isSuppressed = isSuppressed
        self.reason = reason
        self.coordinator = coordinator
    }

    public func body(content: Content) -> some View {
        content
            .onChange(of: isSuppressed) { newValue in
                Task {
                    if newValue {
                        await coordinator.appOpenCoordinator.addSuppression(reason)
                    } else {
                        await coordinator.appOpenCoordinator.removeSuppression(reason)
                    }
                }
            }
            .onAppear {
                if isSuppressed {
                    Task {
                        await coordinator.appOpenCoordinator.addSuppression(reason)
                    }
                }
            }
            .onDisappear {
                Task {
                    await coordinator.appOpenCoordinator.removeSuppression(reason)
                }
            }
    }
}

public extension View {
    /// Overlays a graceful loading HUD while full-screen interstitial or rewarded ads are buffering.
    func adLoadingOverlay(isPresented: Bool, message: LocalizedStringKey = "Loading advertisement...") -> some View {
        modifier(AdLoadingOverlayModifier(isPresented: isPresented, message: message))
    }

    /// Automatically suppresses App Open ads while this view is active (e.g. paywalls, walkthroughs, document pickers).
    func suppressAppOpenAds(when isSuppressed: Bool = true, reason: AppOpenSuppressionReason = .modalPresentationActive) -> some View {
        modifier(AppOpenSuppressionModifier(isSuppressed: isSuppressed, reason: reason))
    }
}
