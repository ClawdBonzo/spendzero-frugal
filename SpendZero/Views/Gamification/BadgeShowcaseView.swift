import SwiftUI

/// Grid display of earned badges with rarity colors and unlock details
struct BadgeShowcaseView: View {
    let gameProfile: GameProfile

    @State private var selectedBadge: BadgeInstance?
    @State private var showDetail = false

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var earnedBadges: [BadgeInstance] {
        // Show most recent badges first, limit to 20
        gameProfile.badges
            .sorted { $0.earnedDate > $1.earnedDate }
            .prefix(20)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Badges")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Unlock badges by achieving milestones")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.paddingLarge)

            // Badge Count
            HStack {
                Text("Earned")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)

                Text("\(gameProfile.badges.count)")
                    .font(AppTheme.headlineFont)
                    .foregroundColor(AppTheme.accentGold)

                Spacer()
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            // Badge Grid
            if earnedBadges.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "medal")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                    Text("No badges yet")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Complete milestones and challenges to earn badges")
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.paddingLarge)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadiusMedium)
                .padding(.horizontal, AppTheme.paddingLarge)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(earnedBadges, id: \.id) { badge in
                        BadgeItemView(badge: badge)
                            .onTapGesture {
                                selectedBadge = badge
                                showDetail = true
                            }
                    }
                }
                .padding(.horizontal, AppTheme.paddingLarge)
            }

            Spacer()
        }
        .padding(.vertical, AppTheme.paddingLarge)
        .background(AppTheme.background)
        .sheet(isPresented: $showDetail) {
            if let badge = selectedBadge {
                BadgeDetailView(badge: badge)
            }
        }
    }
}

// MARK: - Badge Item Component

struct BadgeItemView: View {
    let badge: BadgeInstance

    var body: some View {
        VStack(spacing: 8) {
            // Badge Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(badge.rarity.backgroundColor)

                Image(systemName: badge.badgeID.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(badge.rarity.foregroundColor)
            }
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(badge.rarity.borderColor, lineWidth: 2)
            )
            .shadow(
                color: badge.rarity.glowColor.opacity(0.4),
                radius: 8,
                x: 0,
                y: 2
            )

            // Badge Name
            Text(LocalizedStringKey(badge.badgeID.rawValue))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Rarity Label
            Text(badge.rarity.label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(badge.rarity.foregroundColor)
        }
    }
}

// MARK: - Badge Detail Sheet

struct BadgeDetailView: View {
    let badge: BadgeInstance

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Badge Unlocked")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            ScrollView {
                VStack(spacing: 20) {
                    // Large Badge Display
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(badge.rarity.backgroundColor)

                        Image(systemName: badge.badgeID.icon)
                            .font(.system(size: 60, weight: .semibold))
                            .foregroundColor(badge.rarity.foregroundColor)
                    }
                    .frame(height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(badge.rarity.borderColor, lineWidth: 3)
                    )
                    .shadow(
                        color: badge.rarity.glowColor.opacity(0.5),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                    .padding(.horizontal, AppTheme.paddingLarge)

                    // Badge Info
                    VStack(spacing: 12) {
                        Text(LocalizedStringKey(badge.badgeID.rawValue))
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)

                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(badge.rarity.foregroundColor)
                            Text(badge.rarity.label)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(badge.rarity.foregroundColor)
                        }

                        Text(badge.badgeID.description)
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textSecondary)

                        Divider()
                            .overlay(AppTheme.cardBackgroundLight)
                            .padding(.vertical, 8)

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unlocked")
                                    .font(AppTheme.smallFont)
                                    .foregroundColor(AppTheme.textTertiary)
                                Text(badge.earnedDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.textPrimary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Rarity")
                                    .font(AppTheme.smallFont)
                                    .foregroundColor(AppTheme.textTertiary)
                                Text(badge.rarity.label.uppercased())
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(badge.rarity.foregroundColor)
                            }
                        }
                        .padding(AppTheme.paddingMedium)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                    .padding(.horizontal, AppTheme.paddingLarge)

                    Spacer(minLength: 20)
                }
            }

            // Close Button
            Button(action: { dismiss() }) {
                Text("Got it!")
                    .font(AppTheme.headlineFont)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.paddingMedium)
                    .background(AppTheme.primaryGreen)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
            }
            .padding(.horizontal, AppTheme.paddingLarge)
        }
        .padding(.vertical, AppTheme.paddingLarge)
        .background(AppTheme.background)
    }
}

// MARK: - Preview

#Preview {
    let profile = GameProfile()
    profile.badges = [
        BadgeInstance(badgeID: .sevenDayStreak, rarity: .rare),
        BadgeInstance(badgeID: .thirtyDayStreak, rarity: .epic),
        BadgeInstance(badgeID: .savedFiveHundred, rarity: .common),
        BadgeInstance(badgeID: .perfectWeek, rarity: .rare),
        BadgeInstance(badgeID: .levelTen, rarity: .epic),
    ]

    return BadgeShowcaseView(gameProfile: profile)
        .background(AppTheme.background)
}
