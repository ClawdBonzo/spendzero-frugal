import SwiftUI
import SwiftData

struct DailyLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \SpendingLog.date, order: .reverse) private var spendingLogs: [SpendingLog]
    @Query(sort: \ImpulseLog.date, order: .reverse) private var impulses: [ImpulseLog]
    @State private var showAddSpend = false
    @State private var showAddImpulse = false
    @State private var selectedSegment: Int = {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-LogSegment"), i + 1 < a.count, let v = Int(a[i + 1]) { return v }
        #endif
        return 0
    }()
    @State private var showHeader = false
    @State private var showContent = false

    private var todaySpending: [SpendingLog] {
        let today = Calendar.current.startOfDay(for: Date())
        return spendingLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var todayImpulses: [ImpulseLog] {
        let today = Calendar.current.startOfDay(for: Date())
        return impulses.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var totalSpentToday: Double {
        todaySpending.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Daily summary header — slides down
                    dailySummaryHeader
                        .offset(y: showHeader ? 0 : -20)
                        .opacity(showHeader ? 1 : 0)

                    // Segment picker
                    Picker("View", selection: $selectedSegment) {
                        Text("Spending").tag(0)
                        Text("Impulses").tag(1)
                        Text("Wins").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .tint(AppTheme.primaryGreen)
                    .opacity(showHeader ? 1 : 0)

                    // Content — fades in
                    Group {
                        switch selectedSegment {
                        case 0:
                            spendingSection
                        case 1:
                            impulseSection
                        default:
                            winsSection
                        }
                    }
                    .offset(y: showContent ? 0 : 20)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedSegment)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.top, 8)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                        showHeader = true
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                        showContent = true
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Daily Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Log Spending", systemImage: "dollarsign.circle") {
                            showAddSpend = true
                        }
                        Button("Log Impulse", systemImage: "bolt.fill") {
                            showAddImpulse = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.primaryGreen)
                    }
                }
            }
            .sheet(isPresented: $showAddSpend) {
                AddSpendingView()
            }
            .sheet(isPresented: $showAddImpulse) {
                AddImpulseView()
            }
        }
    }

    // MARK: - Daily Summary

    private var dailySummaryHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Spending")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)

                    Text(totalSpentToday.currencyFormattedDecimal)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(totalSpentToday == 0 ? AppTheme.primaryGreen : AppTheme.destructive)
                        .shadow(color: totalSpentToday == 0 ? AppTheme.primaryGreen.opacity(0.5) : .clear, radius: 8)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: totalSpentToday)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Budget")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)

                    Text((profiles.first?.dailyBudget ?? 50).currencyFormatted)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            // Budget bar
            let budget = profiles.first?.dailyBudget ?? 50
            let ratio = min(totalSpentToday / budget, 1.0)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.cardBackgroundLight)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ratio > 0.8 ? AppTheme.destructive : AppTheme.primaryGreen)
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 8)

            if totalSpentToday == 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppTheme.primaryGreen)
                    Text("No-Spend Day so far! Keep it up!")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryGreen)
                }
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.cardBackground)
        )
    }

    // MARK: - Spending Section

    private var spendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if todaySpending.isEmpty {
                EmptyStateView(
                    icon: "checkmark.shield.fill",
                    title: "No spending today",
                    subtitle: "You're on track for a no-spend day!"
                )
            } else {
                ForEach(todaySpending) { log in
                    SpendingLogRow(log: log)
                }
            }

            SecondaryButton(title: "Log a Purchase", icon: "plus") {
                showAddSpend = true
            }
        }
    }

    // MARK: - Impulse Section

    private var impulseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if todayImpulses.isEmpty {
                EmptyStateView(
                    icon: "brain.head.profile",
                    title: "No impulses logged",
                    subtitle: "Track urges to spend — resisting builds your savings muscle"
                )
            } else {
                ForEach(todayImpulses) { impulse in
                    ImpulseLogRow(impulse: impulse)
                }
            }

            SecondaryButton(title: "Log an Impulse", icon: "bolt.fill") {
                showAddImpulse = true
            }
        }
    }

    // MARK: - Wins Section

    private var winsSection: some View {
        VStack(spacing: 16) {
            let dailyWins = [
                WinItem(icon: "cup.and.saucer.fill", title: "Made coffee at home", saved: Double(5).currencyFormatted),
                WinItem(icon: "fork.knife", title: "Packed lunch", saved: Double(12).currencyFormatted),
                WinItem(icon: "figure.walk", title: "Walked instead of Uber", saved: Double(15).currencyFormatted),
                WinItem(icon: "tv.fill", title: "Free entertainment", saved: Double(15).currencyFormatted),
                WinItem(icon: "bag.fill", title: "Skipped online shopping", saved: Double(30).currencyFormatted)
            ]

            ForEach(dailyWins, id: \.title) { win in
                WinChecklistRow(win: win)
            }
        }
    }
}

// MARK: - Sub Views

struct SpendingLogRow: View {
    let log: SpendingLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.category.icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: log.category.color))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(hex: log.category.color).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(log.category.rawValue))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                if !log.note.isEmpty {
                    Text(log.note)
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("-$\(String(format: "%.2f", log.amount))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.destructive)

                if log.wasImpulse {
                    Text("Impulse")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(AppTheme.warning.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.cardBackground)
        )
    }
}

struct ImpulseLogRow: View {
    let impulse: ImpulseLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: impulse.wasResisted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(impulse.wasResisted ? AppTheme.primaryGreen : AppTheme.destructive)

            VStack(alignment: .leading, spacing: 2) {
                Text(impulse.item)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(LocalizedStringKey(impulse.category.rawValue))
                    .font(AppTheme.smallFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(impulse.estimatedCost.currencyFormatted)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(impulse.wasResisted ? AppTheme.primaryGreen : AppTheme.destructive)

                Text(impulse.wasResisted ? "Saved" : "Spent")
                    .font(AppTheme.smallFont)
                    .foregroundColor(impulse.wasResisted ? AppTheme.primaryGreen : AppTheme.destructive)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.cardBackground)
        )
    }
}

struct WinItem {
    let icon: String
    let title: String
    let saved: String
}

struct WinChecklistRow: View {
    let win: WinItem
    @State private var isChecked = false

    var body: some View {
        Button {
            HapticManager.shared.trigger(isChecked ? .toggleOff : .celebrate)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isChecked ? AppTheme.primaryGreen : AppTheme.textTertiary)

                Image(systemName: win.icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)

                Text(win.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isChecked ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .strikethrough(isChecked)

                Spacer()

                Text(win.saved)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isChecked ? AppTheme.primaryGreen : AppTheme.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(isChecked ? AppTheme.primaryGreen.opacity(0.08) : AppTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(AppTheme.primaryGreen.opacity(0.5))

            Text(title)
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            Text(subtitle)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
