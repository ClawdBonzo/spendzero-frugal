import SwiftUI
import SwiftData

struct AddSpendingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var amount = ""
    @State private var showRevertWarning = false

    private var parsedAmount: Double? { Double.parseAmount(amount) }
    private var willRevertNoSpendDay: Bool {
        !selectedCategory.isEssential && (profiles.first?.hasLoggedToday() ?? false)
    }
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

                        if !amount.isEmpty, parsedAmount == nil {
                            Text("Enter an amount greater than zero")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.destructive)
                        } else if willRevertNoSpendDay {
                            Label("This will un-mark today as a no-spend day", systemImage: "exclamationmark.triangle.fill")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.warning)
                        } else if selectedCategory.isEssential {
                            Label("Essentials don't break your no-spend day", systemImage: "info.circle")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        // Save button
                        PrimaryButton(
                            title: "Log Spending",
                            icon: "checkmark",
                            isEnabled: parsedAmount != nil
                        ) {
                            if willRevertNoSpendDay { showRevertWarning = true } else { saveSpending() }
                        }
                    }
                    .padding(.horizontal, AppTheme.paddingMedium)
                }
            }
            .navigationTitle("Log Spending")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Un-mark today's no-spend day?", isPresented: $showRevertWarning) {
                Button("Log Spending", role: .destructive) { saveSpending() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You already marked today as a win. Logging non-essential spending will remove today from your streak.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    private func saveSpending() {
        guard let amountValue = parsedAmount else { return }
        ProgressEngine.shared.logSpending(
            amount: amountValue,
            category: selectedCategory,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            wasImpulse: wasImpulse,
            profile: profiles.first,
            context: modelContext
        )
        HapticManager.shared.trigger(.toggleOff)
        dismiss()
    }
}
