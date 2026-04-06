import SwiftUI

struct OnboardingNameView: View {
    @Binding var name: String
    let onNext: () -> Void
    @FocusState private var isFocused: Bool
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.accentGold)
                    .symbolEffect(.bounce, value: showContent)

                Text("What should we call your\nwealthy future self?")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("This is the beginning of your\nfinancial transformation")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            VStack(spacing: 12) {
                TextField("", text: $name, prompt: Text("Your name").foregroundColor(AppTheme.textTertiary))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .fill(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                    .stroke(
                                        isFocused ? AppTheme.primaryGreen : AppTheme.textTertiary.opacity(0.3),
                                        lineWidth: 1.5
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
                    Text("Welcome, \(name)! Let's build wealth together.")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryGreen)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, AppTheme.paddingMedium)

            Spacer()

            PrimaryButton(
                title: "Continue",
                icon: "arrow.right",
                isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                onNext()
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, AppTheme.paddingLarge)
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
