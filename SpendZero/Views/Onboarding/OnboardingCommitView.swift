import SwiftUI

struct OnboardingCommitView: View {
    @Binding var days: Int
    let onNext: () -> Void
    @State private var showFlame = false
    @State private var showTitle = false
    @State private var visibleCards: Set<Int> = []
    @State private var flamePulse = false

    private let commitOptions = [7, 14, 21, 30]

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            // Hero flame icon with animated glow — bigger
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accentGold.opacity(0.35), AppTheme.accentGold.opacity(0.04)],
                            center: .center,
                            startRadius: 15,
                            endRadius: 75
                        )
                    )
                    .frame(width: 150, height: 150)
                    .scaleEffect(flamePulse ? 1.15 : 1.0)

                Image(systemName: "flame.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accentGold, Color(hex: "FF6F00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.accentGold.opacity(0.5), radius: 16, y: 4)
                    .symbolEffect(.variableColor.iterative, value: showFlame)
                    .scaleEffect(showFlame ? 1 : 0.3)
            }
            .opacity(showFlame ? 1 : 0)

            // Title + subtitle
            VStack(spacing: 6) {
                Text("How many days can you go no-spend?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Start comfortable — you can always level up")
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
                ForEach(Array(commitOptions.enumerated()), id: \.element) { index, option in
                    CommitOptionCard(
                        days: option,
                        isSelected: days == option,
                        action: {
                            HapticManager.shared.trigger(.cardSelect)
                            withAnimation(.spring(response: 0.3)) {
                                days = option
                            }
                        }
                    )
                    .offset(x: visibleCards.contains(index) ? 0 : -60)
                    .opacity(visibleCards.contains(index) ? 1 : 0)
                }
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            Spacer()

            // Button
            PrimaryButton(title: "I'm Committed!", icon: "checkmark") {
                onNext()
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .padding(.bottom, 28)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                showFlame = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                showTitle = true
            }
            // Stagger cards from left
            for i in 0..<commitOptions.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4 + Double(i) * 0.1)) {
                    visibleCards.insert(i)
                }
            }
            // Flame glow pulse
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(1.0)) {
                flamePulse = true
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
        days == 30 ? "POPULAR" : nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text("\(days)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary)
                    .frame(width: 48)
                    .scaleEffect(isSelected ? 1.15 : 1.0)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 17, weight: .semibold))
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

                    Text("\(days) days no unnecessary spending")
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
