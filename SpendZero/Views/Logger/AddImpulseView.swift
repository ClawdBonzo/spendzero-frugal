import SwiftUI
import SwiftData

struct AddImpulseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    var onImpulseLogged: (() -> Void)?

    @State private var item = ""
    @State private var estimatedCost = ""
    @State private var selectedCategory: SpendCategory = .shopping
    @State private var wasResisted = true
    @State private var triggerNote = ""

    private let copingStrategies = [
        "Waited 24 hours",
        "Walked away",
        "Checked my savings goal",
        "Called a friend",
        "Reminded myself why I'm doing this"
    ]

    @State private var selectedCoping = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Resisted toggle
                        HStack(spacing: 16) {
                            ImpulseToggleButton(
                                title: "Resisted!",
                                icon: "bolt.slash.fill",
                                color: AppTheme.primaryGreen,
                                isSelected: wasResisted
                            ) {
                                withAnimation { wasResisted = true }
                            }

                            ImpulseToggleButton(
                                title: "Gave In",
                                icon: "bolt.fill",
                                color: AppTheme.destructive,
                                isSelected: !wasResisted
                            ) {
                                withAnimation { wasResisted = false }
                            }
                        }

                        // Item name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What was the impulse?")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)

                            TextField("e.g., New sneakers, latte, Amazon order", text: $item)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                        .fill(AppTheme.cardBackground)
                                )
                        }

                        // Cost
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estimated cost")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)

                            HStack {
                                Text("$")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AppTheme.textSecondary)
                                TextField("0", text: $estimatedCost)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(wasResisted ? AppTheme.primaryGreen : AppTheme.destructive)
                                    .keyboardType(.decimalPad)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                    .fill(AppTheme.cardBackground)
                            )
                        }

                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(SpendCategory.allCases) { cat in
                                        Button {
                                            selectedCategory = cat
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: cat.icon)
                                                    .font(.system(size: 12))
                                                Text(cat.rawValue)
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .foregroundColor(selectedCategory == cat ? AppTheme.primaryGreen : AppTheme.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(selectedCategory == cat ? AppTheme.primaryGreen.opacity(0.12) : AppTheme.cardBackground)
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(selectedCategory == cat ? AppTheme.primaryGreen : Color.clear, lineWidth: 1)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Coping strategies
                        if wasResisted {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How did you resist?")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)

                                ForEach(copingStrategies, id: \.self) { strategy in
                                    Button {
                                        selectedCoping = strategy
                                    } label: {
                                        HStack {
                                            Text(strategy)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            if selectedCoping == strategy {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(AppTheme.primaryGreen)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                                .fill(selectedCoping == strategy ? AppTheme.primaryGreen.opacity(0.1) : AppTheme.cardBackground)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Save
                        PrimaryButton(
                            title: wasResisted ? "Log Victory!" : "Log Impulse",
                            icon: wasResisted ? "trophy.fill" : "checkmark",
                            isEnabled: !item.isEmpty && !estimatedCost.isEmpty
                        ) {
                            saveImpulse()
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, AppTheme.paddingMedium)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Log Impulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    private func saveImpulse() {
        guard let cost = Double(estimatedCost) else { return }
        let impulse = ImpulseLog(
            item: item,
            estimatedCost: cost,
            category: selectedCategory,
            wasResisted: wasResisted,
            triggerNote: triggerNote,
            copingStrategy: selectedCoping
        )
        modelContext.insert(impulse)

        if wasResisted {
            let saving = SavingsEntry(
                amount: cost,
                source: .impulseResisted,
                note: "Resisted: \(item)"
            )
            modelContext.insert(saving)

            if let profile = profiles.first {
                profile.totalSaved += cost
            }
        }

        try? modelContext.save()

        // Trigger gamification callback if impulse was resisted
        if wasResisted {
            onImpulseLogged?()
        }

        dismiss()
    }
}

struct ImpulseToggleButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(isSelected ? color : AppTheme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(isSelected ? color.opacity(0.12) : AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
