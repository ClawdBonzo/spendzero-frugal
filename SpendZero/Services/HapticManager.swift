import UIKit

/// Centralized haptic feedback for all app interactions — gamification, navigation, and UI
final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()

    private let lightImpact  = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact  = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact   = UIImpactFeedbackGenerator(style: .soft)
    private let notification  = UINotificationFeedbackGenerator()
    private let selection     = UISelectionFeedbackGenerator()

    private init() {
        // Pre-warm all generators
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        softImpact.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Event Types

    enum HapticEvent {
        // Gamification
        case xpGained
        case levelUp
        case questComplete
        case streakMilestone7Day
        case streakMilestone30Day
        case badgeEarned
        case noSpendDay

        // UI interactions
        case buttonTap           // Primary/CTA buttons
        case cardSelect          // Selecting a subscription card, category chip, etc.
        case tabSwitch           // Tab bar navigation
        case toggleOn            // Any toggle/checkbox turning on
        case toggleOff           // Any toggle/checkbox turning off
        case sheetPresented      // Sheet/modal appearing
        case success             // Generic success (form submit, save, etc.)
        case warning             // Budget threshold, overspend warning
        case error               // Error state
        case swipe               // Swipe/drag interactions
        case celebrate           // Lighter celebration (daily win, impulse resisted)
    }

    // MARK: - Trigger

    func trigger(_ event: HapticEvent) {
        switch event {
        // === Gamification ===
        case .xpGained:
            lightImpact.impactOccurred(intensity: 0.6)

        case .levelUp:
            heavyImpact.impactOccurred()
            after(0.1) { self.notification.notificationOccurred(.success) }
            after(0.25) { self.mediumImpact.impactOccurred(intensity: 0.8) }

        case .questComplete:
            mediumImpact.impactOccurred()
            after(0.12) { self.lightImpact.impactOccurred() }

        case .streakMilestone7Day:
            mediumImpact.impactOccurred(intensity: 0.7)
            after(0.1) { self.lightImpact.impactOccurred() }

        case .streakMilestone30Day:
            notification.notificationOccurred(.success)
            after(0.15) { self.heavyImpact.impactOccurred(intensity: 0.9) }
            after(0.3) { self.mediumImpact.impactOccurred(intensity: 0.6) }

        case .badgeEarned:
            notification.notificationOccurred(.success)
            after(0.12) { self.mediumImpact.impactOccurred() }

        case .noSpendDay:
            notification.notificationOccurred(.success)

        // === UI Interactions ===
        case .buttonTap:
            mediumImpact.impactOccurred(intensity: 0.7)

        case .cardSelect:
            selection.selectionChanged()

        case .tabSwitch:
            lightImpact.impactOccurred(intensity: 0.4)

        case .toggleOn:
            lightImpact.impactOccurred(intensity: 0.6)

        case .toggleOff:
            softImpact.impactOccurred(intensity: 0.3)

        case .sheetPresented:
            softImpact.impactOccurred(intensity: 0.5)

        case .success:
            notification.notificationOccurred(.success)

        case .warning:
            notification.notificationOccurred(.warning)

        case .error:
            notification.notificationOccurred(.error)

        case .swipe:
            lightImpact.impactOccurred(intensity: 0.3)

        case .celebrate:
            mediumImpact.impactOccurred(intensity: 0.8)
            after(0.1) { self.lightImpact.impactOccurred(intensity: 0.5) }
        }

        prepareAll()
    }

    // MARK: - Private

    private func after(_ seconds: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
    }

    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        softImpact.prepare()
        notification.prepare()
        selection.prepare()
    }
}
