import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showPaywall = false
    @State private var showExport = false
    @State private var showResetConfirmation = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    // Profile Section
                    Section {
                        HStack(spacing: 14) {
                            Image("BrandIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile?.displayName ?? "User")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text("Member since \(profile?.createdAt ?? Date(), format: .dateTime.month(.abbreviated).year())")
                                    .font(AppTheme.smallFont)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    }

                    // Stats Section
                    Section("Your Stats") {
                        SettingsRow(icon: "flame.fill", title: "Current Streak", value: "\(profile?.currentStreak ?? 0) days", color: AppTheme.accentGold)
                        SettingsRow(icon: "trophy.fill", title: "Longest Streak", value: "\(profile?.longestStreak ?? 0) days", color: AppTheme.primaryGreen)
                        SettingsRow(icon: "banknote.fill", title: "Total Saved", value: "$\(Int(profile?.totalSaved ?? 0))", color: AppTheme.primaryGreen)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Budget Section
                    Section("Budget") {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(AppTheme.primaryGreen)
                            Text("Daily Budget")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("$\(Int(profile?.dailyBudget ?? 50))")
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        if let profile {
                            Slider(
                                value: Binding(
                                    get: { profile.dailyBudget },
                                    set: { profile.dailyBudget = $0; try? modelContext.save() }
                                ),
                                in: 10...200,
                                step: 5
                            )
                            .tint(AppTheme.primaryGreen)
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Premium Section
                    Section("Premium") {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(AppTheme.accentGold)
                                Text(profile?.isPremium == true ? "Premium Active" : "Upgrade to Premium")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                if profile?.isPremium != true {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                            }
                        }

                        Button {
                            Task {
                                _ = await SubscriptionService.shared.restorePurchases()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(AppTheme.info)
                                Text("Restore Purchases")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Tools Section
                    Section("Tools") {
                        NavigationLink {
                            ExportView()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(AppTheme.info)
                                Text("Export PDF Report")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        NavigationLink {
                            ChallengeLibraryView()
                        } label: {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(AppTheme.accentGold)
                                Text("Challenge Library")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Data Section
                    Section("Data") {
                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(AppTheme.destructive)
                                Text("Reset All Data")
                                    .foregroundColor(AppTheme.destructive)
                            }
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // About
                    Section("About") {
                        HStack {
                            Text("Version")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        HStack {
                            Text("All data stored locally")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(AppTheme.primaryGreen)
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView(onContinue: { showPaywall = false }, urgencyMessage: "Upgrade to unlock all features")
            }
            .alert("Reset All Data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will permanently delete all your data including streaks, savings, and challenge progress. This cannot be undone.")
            }
        }
    }

    private func resetAllData() {
        try? modelContext.delete(model: SpendingLog.self)
        try? modelContext.delete(model: SavingsEntry.self)
        try? modelContext.delete(model: DailyRecord.self)
        try? modelContext.delete(model: ImpulseLog.self)
        try? modelContext.delete(model: ChallengeEntry.self)
        if let profile {
            profile.currentStreak = 0
            profile.longestStreak = 0
            profile.totalSaved = 0
        }
        try? modelContext.save()
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }
}
