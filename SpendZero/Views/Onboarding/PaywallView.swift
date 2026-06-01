import SwiftUI

struct PaywallView: View {
    let onContinue: () -> Void
    /// When true, the paywall cannot be dismissed (trial expired / hard gate)
    var isHardPaywall: Bool = false
    /// Optional urgency message shown at top
    var urgencyMessage: String? = nil

    // Default to Yearly — highest LTV, has 3-day trial
    @State private var selectedOption: String = SubscriptionService.yearlyID
    @State private var subscriptionService = SubscriptionService.shared
    @State private var showError = false

    private var selectedPlan: SubscriptionOption? {
        subscriptionService.offerings.first(where: { $0.id == selectedOption })
    }
    private var selectedHasFreeTrial: Bool { selectedPlan?.hasFreeTrial ?? false }
    private var selectedTrialDays: Int { selectedPlan?.trialDays ?? 0 }

    var body: some View {
        ZStack {
            // Deep dark background with subtle green tint
            LinearGradient(
                colors: [
                    Color(hex: "0A0F0A"),
                    AppTheme.background,
                    Color(hex: "0A100A")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle ambient glow top
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.primaryGreen.opacity(0.12), Color.clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .offset(y: -280)

            VStack(spacing: 0) {
                // — HEADER —
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 20)

                        Image("BrandIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: AppTheme.primaryGreen.opacity(0.5), radius: 10, y: 3)

                        VStack(spacing: 4) {
                            Text("SpendZero Pro")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            Text(isHardPaywall
                                ? "Subscribe to continue your journey"
                                : "Unlock the full SpendZero experience")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, AppTheme.paddingLarge)
                    }
                    .frame(maxWidth: .infinity)

                    // Close button — only shown on soft paywall (during trial)
                    if !isHardPaywall {
                        Button(action: onContinue) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(AppTheme.textTertiary.opacity(0.7))
                        }
                        .padding(.top, 16)
                        .padding(.trailing, AppTheme.paddingLarge)
                    }
                }
                .padding(.bottom, 18)

                // — FEATURES LIST —
                VStack(alignment: .leading, spacing: 10) {
                    FeatureRow(icon: "flame.fill",            color: Color(hex: "FF6B35"), text: "No-spend challenges & streaks")
                    FeatureRow(icon: "chart.bar.fill",        color: AppTheme.info,        text: "Spending analytics & insights")
                    FeatureRow(icon: "bell.badge.fill",       color: AppTheme.accentGold,  text: "Impulse-purchase alerts")
                }
                .padding(.horizontal, AppTheme.paddingLarge + 4)

                Spacer().frame(height: 22)

                // — SUBSCRIPTION CARDS —
                VStack(spacing: 8) {
                    ForEach(subscriptionService.offerings) { option in
                        PremiumSubscriptionCard(
                            option: option,
                            isSelected: selectedOption == option.id
                        ) {
                            HapticManager.shared.trigger(.cardSelect)
                            withAnimation(.spring(response: 0.25)) {
                                selectedOption = option.id
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.paddingLarge)
                .animation(.spring(response: 0.3), value: selectedOption)

                Spacer()

                // — CTA BUTTON —
                VStack(spacing: 8) {
                    PrimaryButton(
                        title: selectedHasFreeTrial
                            ? "Start \(selectedTrialDays)-Day Free Trial"
                            : "Continue",
                        icon: selectedHasFreeTrial ? "lock.open.fill" : "arrow.right"
                    ) {
                        Task {
                            if let option = selectedPlan {
                                let success = await subscriptionService.purchase(option)
                                if success { onContinue() }
                                else if subscriptionService.errorMessage != nil { showError = true }
                            }
                        }
                    }
                    .disabled(subscriptionService.isLoading)
                    .overlay {
                        if subscriptionService.isLoading {
                            ProgressView().tint(AppTheme.background)
                        }
                    }
                    .padding(.horizontal, AppTheme.paddingLarge)

                    // Restore + Legal
                    HStack(spacing: 16) {
                        Button("Restore Purchases") {
                            Task {
                                let restored = await subscriptionService.restorePurchases()
                                if restored { onContinue() }
                            }
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)

                        Button("Terms") {}.font(AppTheme.smallFont).foregroundColor(AppTheme.textTertiary)
                        Button("Privacy") {}.font(AppTheme.smallFont).foregroundColor(AppTheme.textTertiary)
                    }

                    Text(selectedHasFreeTrial
                        ? "\(selectedTrialDays)-day free trial, then auto-renews. Cancel anytime in Settings."
                        : "Payment charged at purchase. Cancel anytime in Settings.")
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.paddingLarge)
                }
                .padding(.bottom, 20)
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK") { subscriptionService.errorMessage = nil }
        } message: {
            Text(subscriptionService.errorMessage ?? "Something went wrong. Please try again.")
        }
        .task {
            await subscriptionService.fetchOfferings()
        }
    }
}

// MARK: - Premium Subscription Card

struct PremiumSubscriptionCard: View {
    let option: SubscriptionOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Left: selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? AppTheme.primaryGreen : AppTheme.textTertiary.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppTheme.primaryGreen)
                            .frame(width: 12, height: 12)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.2), value: isSelected)

                // Middle: title + badges
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(option.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        if option.hasFreeTrial {
                            Text("\(option.trialDays)-DAY FREE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.primaryGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppTheme.primaryGreen.opacity(0.15))
                                .overlay(Capsule().stroke(AppTheme.primaryGreen.opacity(0.4), lineWidth: 0.5))
                                .clipShape(Capsule())
                        }

                        if option.isLifetime {
                            Text("PAY ONCE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.accentGold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppTheme.accentGold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text(option.isLifetime ? "No recurring charges" : option.pricePerWeek)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // Right: price
                VStack(alignment: .trailing, spacing: 1) {
                    Text(option.price)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? AppTheme.primaryGreen : AppTheme.textPrimary)
                    Text(option.period)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                        ? LinearGradient(colors: [AppTheme.primaryGreen.opacity(0.1), AppTheme.primaryGreen.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [AppTheme.cardBackground, AppTheme.cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? AppTheme.primaryGreen : AppTheme.textTertiary.opacity(0.15),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.primaryGreen)
        }
    }
}
