import SwiftUI

struct PaywallView: View {
    let onContinue: () -> Void
    @State private var selectedOption: String = "annual"
    @State private var showContent = false
    @State private var subscriptionService = SubscriptionService.shared

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: onContinue) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                    .padding(.top, 8)

                    // Transformation header with brand icon + paywall illustration
                    VStack(spacing: 16) {
                        Image("BrandIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: AppTheme.primaryGreen.opacity(0.3), radius: 12, y: 4)

                        Image("Onboarding-5")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 140)

                        Text("Unlock Your Full\nSavings Potential")
                            .font(AppTheme.displayFont)
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                    }

                    // Before / After teaser
                    HStack(spacing: 16) {
                        TransformationCard(
                            title: "Before",
                            amount: "$0",
                            subtitle: "saved this month",
                            icon: "arrow.down.right",
                            color: AppTheme.destructive,
                            bgColor: AppTheme.destructive.opacity(0.1)
                        )

                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.primaryGreen)

                        TransformationCard(
                            title: "After 30 Days",
                            amount: "$847",
                            subtitle: "average saved",
                            icon: "arrow.up.right",
                            color: AppTheme.primaryGreen,
                            bgColor: AppTheme.primaryGreen.opacity(0.1)
                        )
                    }

                    // Features
                    VStack(spacing: 12) {
                        FeatureRow(icon: "flame.fill", text: "Unlimited No-Spend Challenges", color: AppTheme.destructive)
                        FeatureRow(icon: "chart.bar.fill", text: "Advanced Spending Analytics", color: AppTheme.info)
                        FeatureRow(icon: "bell.fill", text: "Smart Impulse Alerts", color: AppTheme.accentGold)
                        FeatureRow(icon: "doc.text.fill", text: "PDF Savings Reports", color: AppTheme.primaryGreen)
                        FeatureRow(icon: "rectangle.3.group.fill", text: "Home Screen Widgets", color: Color(hex: "9C27B0"))
                    }

                    // Subscription options
                    VStack(spacing: 10) {
                        ForEach(subscriptionService.offerings) { option in
                            SubscriptionCard(
                                option: option,
                                isSelected: selectedOption == option.id
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedOption = option.id
                                }
                            }
                        }
                    }

                    // CTA
                    PrimaryButton(
                        title: "Start Free Trial",
                        icon: "lock.open.fill"
                    ) {
                        Task {
                            if let option = subscriptionService.offerings.first(where: { $0.id == selectedOption }) {
                                let success = await subscriptionService.purchase(option)
                                if success {
                                    onContinue()
                                }
                            }
                        }
                    }

                    // Restore + Terms
                    VStack(spacing: 8) {
                        Button("Restore Purchases") {
                            Task {
                                let restored = await subscriptionService.restorePurchases()
                                if restored {
                                    onContinue()
                                }
                            }
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)

                        Text("3-day free trial, then auto-renews. Cancel anytime.")
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.textTertiary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Button("Terms") {}
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                            Button("Privacy") {}
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, AppTheme.paddingLarge)
            }
        }
    }
}

struct TransformationCard: View {
    let title: String
    let amount: String
    let subtitle: String
    let icon: String
    let color: Color
    let bgColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(amount)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .foregroundColor(color)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(bgColor)
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.primaryGreen)
        }
        .padding(.horizontal, AppTheme.paddingMedium)
        .padding(.vertical, 10)
    }
}

struct SubscriptionCard: View {
    let option: SubscriptionOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(option.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        if option.isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.background)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accentGold)
                                .clipShape(Capsule())
                        }

                        if option.hasFreeTrial {
                            Text("\(option.trialDays)-DAY FREE TRIAL")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.primaryGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.primaryGreen.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text(option.pricePerWeek)
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(option.price)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(option.period)
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textTertiary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppTheme.primaryGreen : AppTheme.textTertiary)
                    .padding(.leading, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(isSelected ? AppTheme.primaryGreen.opacity(0.08) : AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .stroke(
                                isSelected ? AppTheme.primaryGreen : AppTheme.textTertiary.opacity(0.2),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
