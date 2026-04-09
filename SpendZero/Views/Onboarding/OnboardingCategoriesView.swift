import SwiftUI

struct OnboardingCategoriesView: View {
    @Binding var selected: Set<SpendCategory>
    let onNext: () -> Void
    @State private var showContent = false

    private let categories = SpendCategory.allCases.map { $0 }

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 24)

            // Hero illustration
            Image("Onboarding-3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .opacity(showContent ? 1 : 0)

            // Title + subtitle
            VStack(spacing: 4) {
                Text("Where does your money leak?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Select all that apply")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            // Category grid - scrollable
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(categories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selected.contains(category)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if selected.contains(category) {
                                    selected.remove(category)
                                } else {
                                    selected.insert(category)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.paddingLarge)
            }
            .opacity(showContent ? 1 : 0)

            // Counter + Button
            VStack(spacing: 6) {
                if !selected.isEmpty {
                    Text("\(selected.count) selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.primaryGreen)
                        .transition(.opacity)
                }

                PrimaryButton(
                    title: "Continue",
                    icon: "arrow.right",
                    isEnabled: !selected.isEmpty
                ) {
                    onNext()
                }
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .padding(.bottom, 28)
        }
        .animation(.spring(response: 0.3), value: selected)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}

struct CategoryChip: View {
    let category: SpendCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? AppTheme.primaryGreen : Color(hex: category.color))

                Text(category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppTheme.primaryGreen.opacity(0.12) : AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? AppTheme.primaryGreen : AppTheme.textTertiary.opacity(0.2),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
