import SwiftUI
import StoreKit

struct PaywallView: View {
    let onContinue: () -> Void
    /// When true, the paywall cannot be dismissed (trial expired / hard gate)
    var isHardPaywall: Bool = false
    /// Optional urgency message shown at top
    var urgencyMessage: LocalizedStringKey? = nil

    // Default to Yearly — best value
    @State private var selectedOption: String = SubscriptionService.yearlyID
    @State private var subscriptionService = SubscriptionService.shared
    @State private var alert: PaywallAlert?
    @State private var showRedeemCode = false
    @State private var showExport = false

    private struct PaywallAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var selectedPlan: SubscriptionOption? {
        subscriptionService.offerings.first(where: { $0.id == selectedOption })
    }
    private var selectedHasFreeTrial: Bool { selectedPlan?.hasFreeTrial ?? false }

    /// The weekly plan's per-week cost, used as the anchor for "Save X%".
    private var weeklyBaseline: Double? {
        subscriptionService.offerings
            .first(where: { $0.id == SubscriptionService.weeklyID })?
            .weeklyEquivalent
    }

    /// Percent saved versus paying weekly. Nil for the weekly plan itself / lifetime.
    private func savingsPercent(for option: SubscriptionOption) -> Int? {
        guard option.id != SubscriptionService.weeklyID,
              let baseline = weeklyBaseline, baseline > 0,
              let weekly = option.weeklyEquivalent, weekly < baseline else { return nil }
        let pct = Int(((baseline - weekly) / baseline * 100).rounded())
        return pct >= 5 ? pct : nil
    }

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
              ScrollView(showsIndicators: false) {
               VStack(spacing: 0) {
                // — URGENCY BANNER —
                // Renders the urgency/scarcity copy that every caller already passes in
                // (previously dead — declared but never shown).
                if let urgencyMessage {
                    UrgencyBanner(text: urgencyMessage, isCritical: isHardPaywall)
                        .padding(.horizontal, AppTheme.paddingLarge)
                        .padding(.top, isHardPaywall ? 16 : 8)
                        .padding(.bottom, 2)
                }

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
                                .font(.app(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                Text(isHardPaywall
                                ? "Subscribe to keep going"
                                : "Keep everything you've built")
                                .font(.app(size: 14))
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
                                .font(.app(size: 26))
                                .foregroundColor(AppTheme.textTertiary.opacity(0.7))
                        }
                        .accessibilityLabel(Text("Close"))
                        .padding(.top, 16)
                        .padding(.trailing, AppTheme.paddingLarge)
                    }
                }
                .padding(.bottom, 18)

                // — FEATURES LIST —
                VStack(alignment: .leading, spacing: 9) {
                    FeatureRow(icon: "flame.fill",            color: AppTheme.warning,     text: "Unlimited no-spend challenges & streaks")
                    FeatureRow(icon: "chart.bar.fill",        color: AppTheme.info,        text: "Spending analytics & insights")
                    FeatureRow(icon: "bell.badge.fill",       color: AppTheme.accentGold,  text: "Impulse-purchase alerts")
                    FeatureRow(icon: "rosette",               color: AppTheme.primaryGreen, text: "Level up, earn badges & grow your tree")
                    FeatureRow(icon: "snowflake",             color: Color(hex: "60CFFF"), text: "Streak freezes to protect your progress")
                    FeatureRow(icon: "square.and.arrow.up",   color: AppTheme.info,        text: "Shareable wins & data export")
                }
                .padding(.horizontal, AppTheme.paddingLarge + 4)

                Spacer().frame(height: 18)

                // — SUBSCRIPTION CARDS —
                VStack(spacing: 8) {
                    switch subscriptionService.loadState {
                    case .idle, .loading:
                        ForEach(0..<3, id: \.self) { _ in PlanSkeletonRow() }
                    case .failed(let message):
                        VStack(spacing: 10) {
                            Text(message)
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") { Task { await subscriptionService.fetchOfferings() } }
                                .font(AppTheme.bodyFont.weight(.semibold))
                                .foregroundColor(AppTheme.primaryGreen)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    case .loaded:
                        ForEach(subscriptionService.offerings) { option in
                            PremiumSubscriptionCard(
                                option: option,
                                isSelected: selectedOption == option.id,
                                savingsPercent: savingsPercent(for: option)
                            ) {
                                HapticManager.shared.trigger(.cardSelect)
                                withAnimation(.spring(response: 0.25)) {
                                    selectedOption = option.id
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.paddingLarge)
                .padding(.top, 6)   // headroom for the floating BEST VALUE badge
                .animation(.spring(response: 0.3), value: selectedOption)

                Spacer(minLength: 16)
               }
              }

                // — CTA BUTTON —
                VStack(spacing: 8) {
                    PrimaryButton(
                        verbatimTitle: selectedPlan?.ctaTitle ?? String(localized: "Loading plans…"),
                        icon: selectedHasFreeTrial ? "lock.open.fill" : "arrow.right",
                        isEnabled: selectedPlan != nil && !subscriptionService.isLoading
                    ) {
                        Task {
                            guard let option = selectedPlan else { return }
                            switch await subscriptionService.purchase(option) {
                            case .success:
                                HapticManager.shared.trigger(.celebrate)
                                onContinue()
                            case .cancelled:
                                break
                            case .failed(let message):
                                alert = PaywallAlert(title: String(localized: "Purchase Failed"), message: message)
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

                    Button("Have a code? Redeem it") { showRedeemCode = true }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.accentGold)
                        .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
                            Task {
                                await subscriptionService.refreshAfterCodeRedemption()
                                if subscriptionService.isPremium { onContinue() }
                            }
                        }

                    // Restore + Legal
                    HStack(spacing: 16) {
                        Button("Restore Purchases") {
                            Task {
                                switch await subscriptionService.restorePurchases() {
                                case .restored:
                                    onContinue()
                                case .nothingToRestore:
                                    alert = PaywallAlert(title: String(localized: "Nothing to Restore"),
                                                         message: String(localized: "No active SpendZero purchase was found for this Apple ID."))
                                case .failed(let message):
                                    alert = PaywallAlert(title: String(localized: "Restore Failed"), message: message)
                                }
                            }
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)

                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(AppTheme.smallFont).foregroundColor(AppTheme.textSecondary)
                        Link("Privacy Policy", destination: URL(string: "https://gwlabs.app/privacy")!)
                            .font(AppTheme.smallFont).foregroundColor(AppTheme.textSecondary)
                    }

                    if let plan = selectedPlan {
                        Text(plan.disclosure)
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.paddingLarge)
                    }

                    // Your data is always yours: even behind the hard wall you can read and export it.
                    if isHardPaywall {
                        Button {
                            showExport = true
                        } label: {
                            Label("View & export my data", systemImage: "square.and.arrow.up")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .alert(item: $alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showExport) {
            NavigationStack { ExportView() }
        }
        .task {
            if subscriptionService.loadState != .loaded {
                await subscriptionService.fetchOfferings()
            }
        }
        .onChange(of: subscriptionService.offerings.map(\.id)) { _, ids in
            // Keep the selection valid if the set of plans changes after load.
            if !ids.contains(selectedOption) { selectedOption = ids.first(where: { $0 == SubscriptionService.yearlyID }) ?? ids.first ?? selectedOption }
        }
    }
}

// MARK: - Premium Subscription Card

struct PremiumSubscriptionCard: View {
    let option: SubscriptionOption
    let isSelected: Bool
    var savingsPercent: Int? = nil
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
                            .font(.app(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        if option.hasFreeTrial {
                            Text("\(option.trialDays)-DAY FREE")
                                .font(.app(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.primaryGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppTheme.primaryGreen.opacity(0.15))
                                .overlay(Capsule().stroke(AppTheme.primaryGreen.opacity(0.4), lineWidth: 0.5))
                                .clipShape(Capsule())
                        }

                        if option.isLifetime {
                            Text("PAY ONCE")
                                .font(.app(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.accentGold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppTheme.accentGold.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        if let savingsPercent {
                            Text("SAVE \(savingsPercent)%")
                                .font(.app(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.accentGold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppTheme.accentGold.opacity(0.15))
                                .overlay(Capsule().stroke(AppTheme.accentGold.opacity(0.4), lineWidth: 0.5))
                                .clipShape(Capsule())
                        }
                    }

                    Text(option.isLifetime ? "No recurring charges" : option.pricePerWeek)
                        .font(.app(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // Right: price
                VStack(alignment: .trailing, spacing: 1) {
                    Text(option.price)
                        .font(.app(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? AppTheme.primaryGreen : AppTheme.textPrimary)
                    Text(option.period)
                        .font(.app(size: 10))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AppTheme.primaryGreen.opacity(0.08) : AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? AppTheme.primaryGreen
                                    : (option.isBestValue ? AppTheme.accentGold.opacity(0.5) : AppTheme.textTertiary.opacity(0.15)),
                                lineWidth: isSelected ? 1.5 : (option.isBestValue ? 1 : 0.5)
                            )
                    )
            )
            // Floating "BEST VALUE" badge on the recommended plan — the price anchor.
            .overlay(alignment: .top) {
                if option.isBestValue {
                    Text("BEST VALUE")
                        .font(.app(size: 8.5, weight: .heavy))
                        .foregroundColor(AppTheme.background)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentGold)
                        .clipShape(Capsule())
                        .offset(y: -9)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

// MARK: - Urgency Banner

private struct UrgencyBanner: View {
    let text: LocalizedStringKey
    let isCritical: Bool

    private var tint: Color { isCritical ? AppTheme.destructive : AppTheme.accentGold }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCritical ? "exclamationmark.triangle.fill" : "clock.fill")
                .font(.app(size: 13, weight: .bold))
            Text(text)
                .font(.app(size: 13, weight: .semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Plan Skeleton

private struct PlanSkeletonRow: View {
    @State private var shimmer = false
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.cardBackground)
            .frame(height: 64)
            .opacity(shimmer ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
            .accessibilityLabel("Loading plans")
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.app(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.app(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.app(size: 12, weight: .bold))
                .foregroundColor(AppTheme.primaryGreen)
        }
    }
}
