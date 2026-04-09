import SwiftUI

struct OnboardingNameView: View {
    @Binding var name: String
    let onNext: () -> Void
    @FocusState private var isFocused: Bool
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showField = false
    @State private var ringPulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // Hero section with animated ring
            VStack(spacing: 12) {
                ZStack {
                    // Pulsing ring
                    Circle()
                        .stroke(AppTheme.primaryGreen.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 130, height: 130)
                        .scaleEffect(ringPulse ? 1.08 : 0.95)
                        .opacity(showIcon ? 0.6 : 0)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.primaryGreen.opacity(0.25), AppTheme.primaryGreen.opacity(0.03)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 55
                            )
                        )
                        .frame(width: 110, height: 110)

                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: AppTheme.primaryGreen.opacity(0.5), radius: 12, y: 4)
                        .scaleEffect(showIcon ? 1 : 0.5)
                        .opacity(showIcon ? 1 : 0)
                }

                VStack(spacing: 6) {
                    Text("What should we call your wealthy future self?")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("This is the beginning of your financial transformation")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .offset(y: showTitle ? 0 : 20)
                .opacity(showTitle ? 1 : 0)
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            Spacer().frame(height: 24)

            // Input field with animated entry
            VStack(spacing: 10) {
                TextField("", text: $name, prompt: Text("Your name").foregroundColor(AppTheme.textTertiary))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        isFocused ? AppTheme.primaryGreen : AppTheme.textTertiary.opacity(0.3),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .focused($isFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.continue)
                    .onSubmit {
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            onNext()
                        }
                    }
                    .scaleEffect(showField ? 1 : 0.9)
                    .opacity(showField ? 1 : 0)

                if !name.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .symbolEffect(.pulse, value: name)
                        Text("Welcome, \(name)! Let's build wealth together.")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.primaryGreen)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            Spacer()

            // Button
            PrimaryButton(
                title: "Continue",
                icon: "arrow.right",
                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                onNext()
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .padding(.bottom, 28)
        }
        .animation(.spring(response: 0.4), value: name)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                showIcon = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                showTitle = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5)) {
                showField = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                isFocused = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.8)) {
                ringPulse = true
            }
        }
    }
}
