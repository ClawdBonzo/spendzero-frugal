import SwiftUI
import SwiftData

struct AddSpendingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var selectedCategory: SpendCategory = .coffee
    @State private var note = ""
    @State private var wasImpulse = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Amount input
                        VStack(spacing: 8) {
                            Text("How much did you spend?")
                                .font(AppTheme.headlineFont)
                                .foregroundColor(AppTheme.textPrimary)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Locale.displayCurrencySymbol)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("0.00", text: $amount)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.destructive)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 20)

                        // Category picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 10) {
                                ForEach(SpendCategory.allCases) { cat in
                                    Button {
                                        selectedCategory = cat
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 18))
                                            Text(LocalizedStringKey(cat.rawValue))
                                                .font(.system(size: 9, weight: .medium))
                                                .lineLimit(1)
                                        }
                                        .foregroundColor(selectedCategory == cat ? AppTheme.primaryGreen : AppTheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                                .fill(selectedCategory == cat ? AppTheme.primaryGreen.opacity(0.12) : AppTheme.cardBackground)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                                        .stroke(selectedCategory == cat ? AppTheme.primaryGreen : Color.clear, lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Note
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note (optional)")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)

                            TextField("What was it for?", text: $note)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                        .fill(AppTheme.cardBackground)
                                )
                        }

                        // Impulse toggle
                        Toggle(isOn: $wasImpulse) {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(AppTheme.warning)
                                Text("Was this an impulse buy?")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                        .tint(AppTheme.warning)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                .fill(AppTheme.cardBackground)
                        )

                        // Save button
                        PrimaryButton(
                            title: "Log Spending",
                            icon: "checkmark",
                            isEnabled: !amount.isEmpty
                        ) {
                            saveSpending()
                        }
                    }
                    .padding(.horizontal, AppTheme.paddingMedium)
                }
            }
            .navigationTitle("Log Spending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    private func saveSpending() {
        guard let amountValue = Double(amount) else { return }
        let log = SpendingLog(
            amount: amountValue,
            category: selectedCategory,
            note: note,
            wasImpulse: wasImpulse
        )
        modelContext.insert(log)
        try? modelContext.save()
        WidgetSync.refresh(context: modelContext)
        dismiss()
    }
}
