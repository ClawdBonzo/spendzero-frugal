import SwiftUI

struct OnboardingSpendingQuizView: View {
    @Binding var level: SpendingLevel
    let onNext: () -> Void
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.primaryGradient)

                Text("How would you describe\nyour spending habits?")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Be honest — this helps us personalize\nyour saving strategy")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)

            VStack(spacing: 12) {
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
            .padding(.horizontal, 4)
            .opacity(showContent ? 1 : 0)

            Spacer()

            PrimaryButton(title: "Continue", icon: "arrow.right") {
                onNext()
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, AppTheme.paddingLarge)
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
            HStack(spacing: 14) {
                Text(level.emoji)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("~$\(Int(level.dailyEstimate))/day on non-essentials")
                        .font(AppTheme.captionFont)
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
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(isSelected ? AppTheme.primaryGreen.opacity(0.1) : AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
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
