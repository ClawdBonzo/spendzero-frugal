import SwiftUI
import SwiftData

/// Panel displaying daily and weekly quests with completion tracking and XP rewards
struct QuestPanelView: View {
    let gameProfile: GameProfile

    @Environment(\.modelContext) private var modelContext
    @State private var selectedQuestID: UUID?

    var dailyQuests: [Quest] {
        gameProfile.quests.filter { $0.isDaily && !$0.isExpired }
    }

    var weeklyQuests: [Quest] {
        gameProfile.quests.filter { !$0.isDaily && !$0.isExpired }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Quests")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Complete quests to earn XP and level up")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.paddingLarge)

            ScrollView {
                VStack(spacing: 16) {
                    // Daily Quests Section
                    if !dailyQuests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Daily Quests")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                Text("\(dailyQuests.filter { $0.isCompleted }.count)/\(dailyQuests.count)")
                                    .font(AppTheme.smallFont)
                                    .foregroundColor(AppTheme.accentGold)
                            }
                            .padding(.horizontal, AppTheme.paddingLarge)

                            ForEach(dailyQuests, id: \.id) { quest in
                                QuestCardView(
                                    quest: quest,
                                    isSelected: selectedQuestID == quest.id,
                                    onTap: { selectedQuestID = quest.id },
                                    onToggleComplete: { toggleQuestCompletion(quest) }
                                )
                                .padding(.horizontal, AppTheme.paddingLarge)
                            }
                        }
                    }

                    // Weekly Quests Section
                    if !weeklyQuests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Weekly Quest")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                if weeklyQuests.first?.isCompleted ?? false {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.primaryGreen)
                                }
                            }
                            .padding(.horizontal, AppTheme.paddingLarge)

                            ForEach(weeklyQuests, id: \.id) { quest in
                                QuestCardView(
                                    quest: quest,
                                    isSelected: selectedQuestID == quest.id,
                                    onTap: { selectedQuestID = quest.id },
                                    onToggleComplete: { toggleQuestCompletion(quest) }
                                )
                                .padding(.horizontal, AppTheme.paddingLarge)
                            }
                        }
                    }

                    // Empty State
                    if dailyQuests.isEmpty && weeklyQuests.isEmpty {
                        let allCompleted = !gameProfile.quests.isEmpty
                        VStack(spacing: 12) {
                            Image(systemName: allCompleted ? "checkmark.circle.fill" : "sparkles")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(AppTheme.primaryGreen)
                            Text(allCompleted ? "All quests completed!" : "Fresh quests on the way")
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(allCompleted
                                 ? "New quests will appear tomorrow"
                                 : "Check back soon — your first quests are loading")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.paddingLarge)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                        .padding(.horizontal, AppTheme.paddingLarge)
                    }

                    Spacer(minLength: 20)
                }
            }
        }
        .padding(.vertical, AppTheme.paddingLarge)
        .background(AppTheme.background)
    }

    private func toggleQuestCompletion(_ quest: Quest) {
        quest.isCompleted.toggle()

        if quest.isCompleted {
            // Award XP
            let streak = calculateCurrentStreak()
            let multiplier = GameStateManager.shared.calculateStreakMultiplier(streak: streak)

            _ = gameProfile.grantXP(.questCompleted, streak: streak, multiplier: multiplier)
            HapticManager.shared.trigger(.questComplete)
        }

        try? modelContext.save()
    }

    private func calculateCurrentStreak() -> Int {
        // Placeholder: should link to actual streak from UserProfile
        return 0
    }
}

// MARK: - Quest Card Component

struct QuestCardView: View {
    let quest: Quest
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Completion Toggle
                Button(action: onToggleComplete) {
                    Image(systemName: quest.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(
                            quest.isCompleted ? AppTheme.primaryGreen : AppTheme.textTertiary
                        )
                }
                .buttonStyle(.plain)

                // Quest Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(quest.title)
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textPrimary)
                            .strikethrough(quest.isCompleted)

                        Spacer()

                        // Difficulty Badge
                        Text(LocalizedStringKey(quest.difficulty.rawValue))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(difficultyColor(quest.difficulty))
                            .cornerRadius(4)
                    }

                    Text(quest.details)
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)

                    // Progress Bar
                    if quest.targetValue > 0 {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.cardBackgroundLight)
                                .frame(height: 6)

                            let progress = min(1.0, Double(quest.currentProgress) / Double(quest.targetValue))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.primaryGreen)
                                .frame(width: 280 * progress, height: 6)
                        }
                        .frame(maxWidth: 280)
                    }
                }

                // XP Reward
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(quest.difficulty.baseXP)")
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.accentGold)
                    Text("XP")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(
                        AppTheme.primaryGreen.opacity(isSelected ? 0.4 : 0.1),
                        lineWidth: 1
                    )
            )
            .onTapGesture(perform: onTap)
        }
    }

    private func difficultyColor(_ difficulty: QuestDifficulty) -> Color {
        switch difficulty {
        case .easy:
            return AppTheme.primaryGreen
        case .medium:
            return AppTheme.accentGold
        case .hard:
            return Color(hex: "E84C3D")  // Red/orange
        }
    }
}

#Preview {
    let profile = GameProfile()
    profile.currentLevel = 8

    let quest1 = Quest(
        title: "Zero-Spend Day",
        details: "Don't spend any money today",
        type: .noSpendDays,
        difficulty: .medium,
        targetValue: 1,
        isDaily: true
    )
    let quest2 = Quest(
        title: "Resist 5 Impulses",
        details: "Resist at least 5 impulse purchase attempts",
        type: .impulseResist,
        difficulty: .hard,
        targetValue: 5,
        isDaily: true
    )
    quest2.currentProgress = 2

    profile.quests.append(contentsOf: [quest1, quest2])

    return QuestPanelView(gameProfile: profile)
        .background(AppTheme.background)
}
