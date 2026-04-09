import SwiftUI

struct OnboardingSpendingQuizView: View {
    @Binding var level: SpendingLevel
    let onNext: () -> Void
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 24)

            // Hero illustration
            Image("Onboarding-2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .opacity(showContent ? 1 : 0)

            // Title + subtitle
            VStack(spacing: 4) {
                Text("Describe your spending habits")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Be honest — we'll personalize your strategy")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            // Compact option cards
            VStack(spacing: 6) {
                ForEach(SpendingLevel.allCases, id: \.self) { option in
                    SpendingLevelCard(
                        level: option,
                        isSelected: level == option
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            level = option
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .opacity(showContent ? 1 : 0)

            Spacer()

            // Button
            PrimaryButton(title: "Continue", icon: "arrow.right") {
                onNext()
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .padding(.bottom, 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
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
            HStack(spacing: 10) {
                Text(level.emoji)
                    .font(.system(size: 22))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(level.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("~$\(Int(level.dailyEstimate))/day on non-essentials")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.primaryGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppTheme.primaryGreen.opacity(0.1) : AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? AppTheme.primaryGreen : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
