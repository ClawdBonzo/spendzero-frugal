import UIKit

/// Singleton service managing haptic feedback for gamification events
final class HapticManager {
    static let shared = HapticManager()

    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    enum GameHapticEvent {
        /// Light feedback when XP is earned
        case xpGained
        /// Heavy feedback + success notification for level-up
        case levelUp
        /// Pattern: light-pause-light for quest completion
        case questComplete
        /// Light taps for 7-day and 30-day streaks
        case streakMilestone7Day
        case streakMilestone30Day
        /// Success notification + impact for badge earned
        case badgeEarned
        /// Gentle confirmation for daily no-spend day
        case noSpendDay
    }

    /// Trigger haptic feedback for a game event
    func trigger(_ event: GameHapticEvent) {
        // Check if haptics are enabled in settings
        guard isHapticsEnabled() else { return }

        switch event {
        case .xpGained:
            impactGenerator.impactOccurred()

        case .levelUp:
            // Heavy impact + success notification
            heavyImpactGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.notificationGenerator.notificationOccurred(.success)
            }

        case .questComplete:
            // Light-pause-light pattern
            impactGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.impactGenerator.impactOccurred()
            }

        case .streakMilestone7Day:
            // 2 light taps
            impactGenerator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.impactGenerator.impactOccurred()
            }

        case .streakMilestone30Day:
            // Success notification + light impact
            notificationGenerator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.impactGenerator.impactOccurred()
            }

        case .badgeEarned:
            // Success notification + light impact
            notificationGenerator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.impactGenerator.impactOccurred()
            }

        case .noSpendDay:
            // Gentle success confirmation
            notificationGenerator.notificationOccurred(.success)
        }

        // Prepare for next potential feedback
        impactGenerator.prepare()
        heavyImpactGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Check if haptic feedback is enabled
    private func isHapticsEnabled() -> Bool {
        // Could check UserDefaults for haptics toggle if added to Settings
        // For now, assume haptics are enabled
        return UIDevice.current.value(forKey: "_feedbackSupported") as? Bool ?? true
    }
}
