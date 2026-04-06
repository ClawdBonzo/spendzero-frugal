import SwiftUI

struct OnboardingCommitView: View {
    @Binding var days: Int
    let onNext: () -> Void
    @State private var showContent = false

    private let commitOptions = [7, 14, 21, 30]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accentGold, AppTheme.destructive],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .symbolEffect(.variableColor.iterative, value: showContent)

                Text("How many days can you\ncommit to a no-spend\nchallenge?")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Start where you're comfortable —\nyou can always level up")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)

            VStack(spacing: 12) {
                ForEach(commitOptions, id: \.self) { option in
                    CommitOptionCard(
                        days: option,
                        isSelected: days == option,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                days = option
                            }
                        }
                    )
                }
            }
            .opacity(showContent ? 1 : 0)

            Spacer()

            PrimaryButton(title: "I'm Committed!", icon: "checkmark") {
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

struct CommitOptionCard: View {
    let days: Int
    let isSelected: Bool
    let action: () -> Void

    private var label: String {
        switch days {
        case 7: return "Starter"
        case 14: return "Building Momentum"
        case 21: return "Habit Former"
        case 30: return "Full Transformation"
        default: return "\(days) Days"
        }
    }

    private var badge: String? {
        days == 30 ? "MOST POPULAR" : nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text("\(days)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.background)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accentGold)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(days) days of no unnecessary spending")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.primaryGreen)
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
