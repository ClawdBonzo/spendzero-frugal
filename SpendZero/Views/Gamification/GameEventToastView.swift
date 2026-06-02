import SwiftUI

/// Toast notification for gamification events (quest complete, streak milestone, etc.)
struct GameEventToastView: View {
    let event: GameEventType
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 100
    @State private var opacity: Double = 0
    @State private var dismissTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: event.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(event.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(event.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                if let xpReward = event.xpReward {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("+\(xpReward) XP")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.accentGold)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(event.color.opacity(0.3), lineWidth: 1)
            )
        }
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            event.haptic()
            withAnimation(.easeOut(duration: 0.3)) {
                offset = 0
                opacity = 1.0
            }

            dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                withAnimation(.easeIn(duration: 0.3)) {
                    offset = 100
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
        .onDisappear {
            dismissTimer?.invalidate()
        }
    }
}

// MARK: - Game Event Type

enum GameEventType {
    case questComplete(title: String, xp: Int)
    case streakMilestone(days: Int)
    case nospendDayRecorded
    case impulseResisted
    case challengeComplete(title: String)
    case savingsRecorded(amount: Double)
    case luckyBonus(xp: Int)
    case streakFrozen(daysUsed: Int)

    var title: String {
        switch self {
        case .questComplete(let title, _):
            return "Quest Complete!"
        case .streakMilestone(let days):
            return "\(days)-Day Streak! 🔥"
        case .nospendDayRecorded:
            return "No-Spend Day!"
        case .impulseResisted:
            return "Impulse Resisted! ⚡️"
        case .challengeComplete(let title):
            return "Challenge Complete!"
        case .savingsRecorded:
            return "Savings Recorded!"
        case .luckyBonus:
            return "Lucky Bonus! 🍀"
        case .streakFrozen:
            return "Streak Freeze Used 🧊"
        }
    }

    var subtitle: String {
        switch self {
        case .questComplete(let title, _):
            return title
        case .streakMilestone(let days):
            return "Amazing consistency!"
        case .nospendDayRecorded:
            return "Great job staying on track!"
        case .impulseResisted:
            return "You beat the urge — money saved!"
        case .challengeComplete(let title):
            return title
        case .savingsRecorded(let amount):
            return String(format: "Saved $%.2f", amount)
        case .luckyBonus:
            return "Your XP was doubled!"
        case .streakFrozen(let days):
            return days <= 1
                ? "We saved your streak from a missed day"
                : "We covered \(days) missed days for you"
        }
    }

    var icon: String {
        switch self {
        case .questComplete:
            return "checkmark.circle.fill"
        case .streakMilestone:
            return "flame.fill"
        case .nospendDayRecorded:
            return "checkmark.seal.fill"
        case .impulseResisted:
            return "bolt.slash.fill"
        case .challengeComplete:
            return "trophy.fill"
        case .savingsRecorded:
            return "banknote.fill"
        case .luckyBonus:
            return "sparkles"
        case .streakFrozen:
            return "snowflake"
        }
    }

    var color: Color {
        switch self {
        case .questComplete:
            return AppTheme.primaryGreen
        case .streakMilestone:
            return Color(hex: "FF6B4A")
        case .nospendDayRecorded:
            return AppTheme.primaryGreen
        case .impulseResisted:
            return AppTheme.info
        case .challengeComplete:
            return AppTheme.accentGold
        case .savingsRecorded:
            return AppTheme.accentGold
        case .luckyBonus:
            return AppTheme.accentGold
        case .streakFrozen:
            return Color(hex: "60CFFF")
        }
    }

    var xpReward: Int? {
        switch self {
        case .questComplete(_, let xp):
            return xp
        case .streakMilestone:
            return 25
        case .nospendDayRecorded:
            return 100
        case .impulseResisted:
            return 25
        case .challengeComplete:
            return 30
        case .savingsRecorded:
            return nil
        case .luckyBonus(let xp):
            return xp
        case .streakFrozen:
            return nil
        }
    }

    func haptic() {
        switch self {
        case .questComplete:
            HapticManager.shared.trigger(.questComplete)
        case .streakMilestone(let days):
            if days >= 30 {
                HapticManager.shared.trigger(.streakMilestone30Day)
            } else {
                HapticManager.shared.trigger(.streakMilestone7Day)
            }
        case .nospendDayRecorded:
            HapticManager.shared.trigger(.noSpendDay)
        case .impulseResisted:
            HapticManager.shared.trigger(.celebrate)
        case .challengeComplete:
            HapticManager.shared.trigger(.questComplete)
        case .savingsRecorded:
            HapticManager.shared.trigger(.xpGained)
        case .luckyBonus:
            HapticManager.shared.trigger(.badgeEarned)
        case .streakFrozen:
            HapticManager.shared.trigger(.warning)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        GameEventToastView(
            event: .questComplete(title: "Resist 5 Impulses", xp: 100),
            onDismiss: {}
        )

        GameEventToastView(
            event: .streakMilestone(days: 7),
            onDismiss: {}
        )

        GameEventToastView(
            event: .nospendDayRecorded,
            onDismiss: {}
        )
    }
    .padding()
    .background(AppTheme.background)
}
