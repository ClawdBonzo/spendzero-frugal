import SwiftUI

struct OnboardingLoadingView: View {
    let userName: String
    let onComplete: () -> Void

    @State private var progress1: CGFloat = 0
    @State private var progress2: CGFloat = 0
    @State private var progress3: CGFloat = 0
    @State private var showSocialProof = false
    @State private var currentFact = 0
    @State private var showComplete = false

    private let socialProofFacts = [
        "127,000+ users saved $2.3M last month",
        "Average user saves $847 in their first 30 days",
        "92% of users report fewer impulse purchases",
        "Users who complete 30 days save 3x more"
    ]

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .symbolEffect(.rotate, value: !showComplete)

                Text("Building your \(challengeText)\nNo-Spend Plan")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                if !userName.isEmpty {
                    Text("for \(userName)")
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.primaryGreen)
                }
            }

            VStack(spacing: 20) {
                LoadingProgressRow(
                    icon: "brain.head.profile",
                    title: "Analyzing spending patterns",
                    progress: progress1
                )

                LoadingProgressRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Calculating savings potential",
                    progress: progress2
                )

                LoadingProgressRow(
                    icon: "trophy.fill",
                    title: "Creating personalized challenges",
                    progress: progress3
                )
            }
            .padding(.horizontal, AppTheme.paddingMedium)

            if showSocialProof {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.primaryGreen)

                        Text(socialProofFacts[currentFact])
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id(currentFact)
                }
                .animation(.easeInOut(duration: 0.4), value: currentFact)
            }

            Spacer()

            if showComplete {
                PrimaryButton(title: "See Your Plan", icon: "sparkles") {
                    onComplete()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 40)
            }
        }
        .padding(.horizontal, AppTheme.paddingLarge)
        .onAppear {
            startLoadingAnimation()
        }
    }

    private var challengeText: String {
        "30-Day"
    }

    private func startLoadingAnimation() {
        // Progress bar 1
        withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
            progress1 = 1.0
        }

        // Progress bar 2
        withAnimation(.easeInOut(duration: 1.8).delay(1.5)) {
            progress2 = 1.0
        }

        // Progress bar 3
        withAnimation(.easeInOut(duration: 1.3).delay(3.0)) {
            progress3 = 1.0
        }

        // Social proof
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            showSocialProof = true
        }

        // Rotate social proof facts
        for i in 1..<socialProofFacts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.5 + 1.0) {
                withAnimation {
                    currentFact = i
                }
            }
        }

        // Show complete button
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showComplete = true
            }
        }
    }
}

struct LoadingProgressRow: View {
    let icon: String
    let title: String
    let progress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(progress >= 1.0 ? AppTheme.primaryGreen : AppTheme.textSecondary)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.primaryGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.cardBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.primaryGradient)
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
