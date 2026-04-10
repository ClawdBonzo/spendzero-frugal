import SwiftUI

struct PaywallView: View {
    let onContinue: () -> Void
    @State private var selectedOption: String = SubscriptionService.monthlyID
    @State private var subscriptionService = SubscriptionService.shared
    @State private var showError = false
    @State private var showContent = false

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
                // — COMPACT HEADER —
                ZStack(alignment: .topTrailing) {
                    // Header content
                    VStack(spacing: 6) {
                        Spacer().frame(height: 16)

                        // Icon + title row
                        HStack(spacing: 10) {
                            Image("BrandIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: AppTheme.primaryGreen.opacity(0.5), radius: 6, y: 2)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("SpendZero Pro")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Unlock your full savings potential")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, AppTheme.paddingLarge)

                        // Stats strip
                        HStack(spacing: 0) {
                            StatPill(value: "$847", label: "avg saved/month")
                            Divider()
                                .frame(height: 24)
                                .background(AppTheme.textTertiary.opacity(0.3))
                            StatPill(value: "92%", label: "less impulse buying")
                            Divider()
                                .frame(height: 24)
                                .background(AppTheme.textTertiary.opacity(0.3))
                            StatPill(value: "127K+", label: "active users")
                        }
                        .padding(.horizontal, AppTheme.paddingLarge)
                        .padding(.bottom, 14)
                    }

                    // Close button
                    Button(action: onContinue) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(AppTheme.textTertiary.opacity(0.7))
                    }
                    .padding(.top, 16)
                    .padding(.trailing, AppTheme.paddingLarge)
                }
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(AppTheme.primaryGreen.opacity(0.2)),
                    alignment: .bottom
                )

                // — FEATURES (compact) —
                HStack(spacing: 0) {
                    CompactFeature(icon: "flame.fill",             text: "No-Spend Challenges", color: Color(hex: "FF6B35"))
                    CompactFeature(icon: "chart.bar.fill",         text: "Spending Analytics",  color: AppTheme.info)
                    CompactFeature(icon: "bell.badge.fill",        text: "Impulse Alerts",      color: AppTheme.accentGold)
                    CompactFeature(icon: "square.grid.2x2.fill",   text: "Widgets",             color: Color(hex: "9C27B0"))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)

                // — FREE TRIAL BANNER (only when selected plan has trial) —
                if selectedHasFreeTrial {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.primaryGreen)
                        Text("\(selectedTrialDays)-DAY FREE TRIAL INCLUDED")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.primaryGreen)
                        Spacer()
                        Text("No charge today")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.primaryGreen.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppTheme.primaryGreen.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, AppTheme.paddingLarge)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(response: 0.3), value: selectedHasFreeTrial)
                }

                Spacer().frame(height: 10)

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

                Spacer().frame(height: 14)

                // — SOCIAL PROOF —
                VStack(spacing: 8) {
                    TestimonialRow(
                        text: "Saved $1,200 in my first month. Game changer!",
                        name: "Sarah K.",
                        stars: 5
                    )
                    TestimonialRow(
                        text: "Finally broke my impulse buying habit.",
                        name: "Marcus T.",
                        stars: 5
                    )
                }
                .padding(.horizontal, AppTheme.paddingLarge)

                Spacer()

                // — CTA BUTTON —
                VStack(spacing: 6) {
                    PrimaryButton(
                        title: selectedHasFreeTrial
                            ? "Start \(selectedTrialDays)-Day Free Trial"
                            : "Get Pro Access",
                        icon: selectedHasFreeTrial ? "lock.open.fill" : "crown.fill"
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

    private var savingsText: String? {
        // Yearly: ~81% cheaper than weekly ($49.99/yr vs $4.99/wk * 52 = $259.48)
        if option.id == SubscriptionService.yearlyID {
            return "Save 81% vs weekly"
        }
        // Monthly: ~63% cheaper than weekly ($7.99/mo * 12 = $95.88 vs $259.48/yr)
        if option.id == SubscriptionService.monthlyID {
            return "Save 63% vs weekly"
        }
        return nil
    }

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

                        if option.isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppTheme.accentGold)
                                .clipShape(Capsule())
                        }

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

                    if let savings = savingsText {
                        Text(savings)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.primaryGreen.opacity(0.8))
                    } else {
                        Text(option.isLifetime ? "No recurring charges" : option.pricePerWeek)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                    }
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
                                isSelected
                                    ? (option.isBestValue ? AppTheme.accentGold : AppTheme.primaryGreen)
                                    : AppTheme.textTertiary.opacity(0.15),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
            )
            // Gold glow for best value when selected
            .shadow(
                color: isSelected && option.isBestValue ? AppTheme.accentGold.opacity(0.2) : .clear,
                radius: 8, y: 2
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentGold], startPoint: .leading, endPoint: .trailing)
                )
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CompactFeature: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TestimonialRow: View {
    let text: String
    let name: String
    let stars: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.accentGold)
                    }
                }
                Text("\"\(text)\"")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .italic()
                    .lineLimit(2)
                Text("— \(name)")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textTertiary)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.textTertiary.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
}
