import SwiftUI

struct OnboardingCategoriesView: View {
    @Binding var selected: Set<SpendCategory>
    let onNext: () -> Void
    @State private var showContent = false

    private let categories: [SpendCategory] = SpendCategory.allCases.filter { $0 != .other }

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.accentGold)

                Text("Which categories leak\nthe most money?")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Select all that apply — we'll help\nyou plug these leaks")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
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
            }
            .padding(.horizontal, 4)
            .opacity(showContent ? 1 : 0)

            if !selected.isEmpty {
                Text("\(selected.count) categories selected")
                    .font(AppTheme.captionFont)
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
            .padding(.bottom, 40)
        }
        .padding(.horizontal, AppTheme.paddingLarge)
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
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppTheme.primaryGreen : Color(hex: category.color))

                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(isSelected ? AppTheme.primaryGreen.opacity(0.12) : AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
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
