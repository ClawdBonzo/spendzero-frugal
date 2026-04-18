import SwiftUI

struct OnboardingCategoriesView: View {
    @Binding var selected: Set<SpendCategory>
    let onNext: () -> Void
    @State private var showImage = false
    @State private var showTitle = false
    @State private var showGrid = false
    @State private var visibleChips: Set<Int> = []

    private let categories = SpendCategory.allCases.map { $0 }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Hero illustration — bigger
            Image("Onboarding-3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: AppTheme.primaryGreen.opacity(0.3), radius: 14, y: 6)
                .scaleEffect(showImage ? 1 : 0.8)
                .opacity(showImage ? 1 : 0)

            // Title + subtitle
            VStack(spacing: 6) {
                Text("Where does your money leak?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Select all that apply")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppTheme.paddingLarge)
            .offset(y: showTitle ? 0 : 15)
            .opacity(showTitle ? 1 : 0)

            // Category grid — larger chips, fills space
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    CategoryChip(
                        category: category,
                        isSelected: selected.contains(category)
                    ) {
                        HapticManager.shared.trigger(selected.contains(category) ? .toggleOff : .toggleOn)
                        withAnimation(.spring(response: 0.3)) {
                            if selected.contains(category) {
                                selected.remove(category)
                            } else {
                                selected.insert(category)
                            }
                        }
                    }
                    .scaleEffect(visibleChips.contains(index) ? 1 : 0.7)
                    .opacity(visibleChips.contains(index) ? 1 : 0)
                }
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            Spacer()

            // Counter + Button
            VStack(spacing: 6) {
                if !selected.isEmpty {
                    Text("\(selected.count) selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.primaryGreen)
                        .transition(.scale.combined(with: .opacity))
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                showImage = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25)) {
                showTitle = true
            }
            // Stagger chips appearing in wave pattern
            for i in 0..<categories.count {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.35 + Double(i) * 0.05)) {
                    visibleChips.insert(i)
                }
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
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppTheme.primaryGreen : Color(hex: category.color))
                    .symbolEffect(.bounce, value: isSelected)

                Text(category.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
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
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
