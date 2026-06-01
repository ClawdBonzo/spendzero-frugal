import SwiftUI
import SwiftData

struct ChallengeLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChallengeEntry.title) private var challenges: [ChallengeEntry]
    @State private var selectedCategory: ChallengeCategory?
    @State private var showCreateChallenge = false

    private var filteredChallenges: [ChallengeEntry] {
        if let category = selectedCategory {
            return challenges.filter { $0.category == category }
        }
        return challenges
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Active challenge
                    if let active = challenges.first(where: \.isActive) {
                        ActiveChallengeCard(challenge: active)
                    }

                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryFilterChip(title: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(ChallengeCategory.allCases, id: \.self) { cat in
                                CategoryFilterChip(
                                    title: cat.rawValue,
                                    isSelected: selectedCategory == cat
                                ) {
                                    selectedCategory = cat
                                }
                            }
                        }
                    }

                    // Challenge cards
                    if filteredChallenges.isEmpty {
                        VStack(spacing: 16) {
                            EmptyStateView(
                                icon: "trophy.fill",
                                title: "No challenges yet",
                                subtitle: "Start your first challenge to begin saving!"
                            )

                            PrimaryButton(title: "Create Challenge", icon: "plus") {
                                showCreateChallenge = true
                            }
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredChallenges) { challenge in
                                ChallengeCard(challenge: challenge) {
                                    startChallenge(challenge)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.top, 8)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateChallenge = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.primaryGreen)
                    }
                }
            }
            .sheet(isPresented: $showCreateChallenge) {
                CreateChallengeView()
            }
            .onAppear {
                seedDefaultChallenges()
            }
        }
    }

    private func startChallenge(_ challenge: ChallengeEntry) {
        // Deactivate other challenges
        challenges.forEach { $0.isActive = false }
        challenge.isActive = true
        challenge.startDate = Date()
        challenge.completedDays = 0
        try? modelContext.save()
    }

    private func seedDefaultChallenges() {
        guard challenges.isEmpty else { return }

        let defaults: [(String, String, Int, ChallengeCategory, ChallengeDifficulty, Double)] = [
            ("7-Day No-Spend Sprint", "Go 7 days without any unnecessary spending. Essentials like groceries and bills are OK.", 7, .noSpend, .easy, 150),
            ("Coffee Detox Week", "Skip the coffee shop for a full week. Make your coffee at home instead.", 7, .noSpend, .easy, 35),
            ("14-Day Meal Prep Master", "Prepare all your meals at home for 14 days. No eating out or delivery.", 14, .mealPrep, .medium, 280),
            ("Subscription Audit", "Review and cancel all subscriptions you don't actively use.", 3, .subscription, .easy, 100),
            ("30-Day No-Spend Challenge", "The ultimate challenge: 30 days of only essential spending.", 30, .noSpend, .hard, 900),
            ("Impulse Control Bootcamp", "Log every impulse for 21 days. Aim to resist 80% of them.", 21, .impulse, .medium, 500),
            ("Minimalist Week", "Don't buy anything non-essential for 7 days. Focus on using what you already have.", 7, .minimalist, .easy, 200),
            ("Saving Sprint", "Save an extra $50/day for 14 days by cutting all discretionary spending.", 14, .saving, .hard, 700),
            ("No-Delivery Month", "No food delivery apps for an entire month. Cook or pick up instead.", 30, .mealPrep, .medium, 360),
            ("Digital Detox Shopping", "Uninstall all shopping apps for 14 days. Remove saved cards from browsers.", 14, .impulse, .medium, 400)
        ]

        for (title, desc, days, cat, diff, savings) in defaults {
            let entry = ChallengeEntry(
                title: title,
                challengeDescription: desc,
                durationDays: days,
                category: cat,
                difficulty: diff,
                estimatedSavings: savings
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }
}

// MARK: - Subviews

struct ActiveChallengeCard: View {
    let challenge: ChallengeEntry

    private var progress: Double {
        guard challenge.durationDays > 0 else { return 0 }
        return min(1.0, Double(challenge.completedDays) / Double(challenge.durationDays))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("ACTIVE CHALLENGE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.primaryGreen)

                        Circle()
                            .fill(AppTheme.primaryGreen)
                            .frame(width: 6, height: 6)
                    }

                    Text(challenge.title)
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()

                Image(systemName: challenge.category.icon)
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.accentGold)
            }

            // Progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Day \(challenge.completedDays) of \(challenge.durationDays)")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryGreen)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.cardBackgroundLight)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.primaryGradient)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)
            }

            HStack {
                Label("Est. savings: $\(Int(challenge.estimatedSavings))", systemImage: "dollarsign.circle.fill")
                    .font(AppTheme.smallFont)
                    .foregroundColor(AppTheme.accentGold)
                Spacer()
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL)
                        .stroke(AppTheme.primaryGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ChallengeCard: View {
    let challenge: ChallengeEntry
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: challenge.category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: challenge.difficulty.color))

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(challenge.difficulty.rawValue))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: challenge.difficulty.color))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: challenge.difficulty.color).opacity(0.15))
                            .clipShape(Capsule())

                        Text("\(challenge.durationDays) days")
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                if challenge.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.primaryGreen)
                }
            }

            Text(challenge.challengeDescription)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(2)

            HStack {
                Label("Save ~$\(Int(challenge.estimatedSavings))", systemImage: "dollarsign.circle")
                    .font(AppTheme.smallFont)
                    .foregroundColor(AppTheme.accentGold)

                Spacer()

                if !challenge.isActive && !challenge.isCompleted {
                    Button("Start") {
                        onStart()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.background)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.primaryGreen)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.cardBackground)
        )
    }
}

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? AppTheme.background : AppTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.primaryGreen : AppTheme.cardBackground)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CreateChallengeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var days = 7
    @State private var category: ChallengeCategory = .noSpend
    @State private var difficulty: ChallengeDifficulty = .easy
    @State private var estimatedSavings = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Challenge Name")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("My Challenge", text: $title)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium).fill(AppTheme.cardBackground))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("What's the challenge?", text: $description, axis: .vertical)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(3...6)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium).fill(AppTheme.cardBackground))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration: \(days) days")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                            Slider(value: Binding(
                                get: { Double(days) },
                                set: { days = Int($0) }
                            ), in: 1...90, step: 1)
                            .tint(AppTheme.primaryGreen)
                        }

                        Picker("Category", selection: $category) {
                            ForEach(ChallengeCategory.allCases, id: \.self) { cat in
                                Text(LocalizedStringKey(cat.rawValue)).tag(cat)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(ChallengeDifficulty.allCases, id: \.self) { diff in
                                Text(LocalizedStringKey(diff.rawValue)).tag(diff)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estimated Savings ($)")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("100", text: $estimatedSavings)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .keyboardType(.decimalPad)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium).fill(AppTheme.cardBackground))
                        }

                        PrimaryButton(title: "Create Challenge", icon: "plus", isEnabled: !title.isEmpty) {
                            let entry = ChallengeEntry(
                                title: title,
                                challengeDescription: description,
                                durationDays: days,
                                category: category,
                                difficulty: difficulty,
                                estimatedSavings: Double(estimatedSavings) ?? 0
                            )
                            modelContext.insert(entry)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                    .padding(.horizontal, AppTheme.paddingMedium)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }
}
