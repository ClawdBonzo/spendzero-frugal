import SwiftUI

struct OnboardingNameView: View {
    @Binding var name: String
    let onNext: () -> Void
    @FocusState private var isFocused: Bool
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // Hero section
            VStack(spacing: 12) {
                ZStack {
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
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer().frame(height: 24)

            // Input field
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

                if !name.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
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
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}
