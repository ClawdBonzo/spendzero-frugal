import SwiftUI

struct OnboardingSpendingQuizView: View {
    @Binding var level: SpendingLevel
    let onNext: () -> Void
    @State private var showImage = false
    @State private var showTitle = false
    @State private var showCards = false
    @State private var visibleCards: Set<Int> = []

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            // Hero illustration — bigger
            Image("Onboarding-2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: AppTheme.primaryGreen.opacity(0.3), radius: 16, y: 6)
                .scaleEffect(showImage ? 1 : 0.8)
                .opacity(showImage ? 1 : 0)

            // Title + subtitle
            VStack(spacing: 6) {
                Text("Describe your spending habits")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Be honest — we'll personalize your strategy")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .offset(y: showTitle ? 0 : 15)
            .opacity(showTitle ? 1 : 0)

            // Larger option cards
            VStack(spacing: 10) {
                ForEach(Array(SpendingLevel.allCases.enumerated()), id: \.element) { index, option in
                    SpendingLevelCard(
                        level: option,
                        isSelected: level == option
                    ) {
                        HapticManager.shared.trigger(.cardSelect)
                        withAnimation(.spring(response: 0.3)) {
                            level = option
                        }
                    }
                    .offset(x: visibleCards.contains(index) ? 0 : 60)
                    .opacity(visibleCards.contains(index) ? 1 : 0)
                }
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            Spacer()

            // Button — pinned at bottom
            PrimaryButton(title: "Continue", icon: "arrow.right") {
                onNext()
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .padding(.bottom, 28)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                showImage = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25)) {
                showTitle = true
            }
            for i in 0..<SpendingLevel.allCases.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.35 + Double(i) * 0.1)) {
                    visibleCards.insert(i)
                }
            }
        }
    }
}

struct SpendingLevelCard: View {
    let level: SpendingLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: level.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(hex: level.iconColorHex))
                    .frame(width: 42)
                    .scaleEffect(isSelected ? 1.2 : 1.0)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(level.rawValue))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("~$\(Int(level.dailyEstimate))/day on non-essentials")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.primaryGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AppTheme.primaryGreen.opacity(0.1) : AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? AppTheme.primaryGreen : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
