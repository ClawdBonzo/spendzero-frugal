import SwiftUI
import SwiftData

struct DailyLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    // Today-only queries (predicated so SwiftData doesn't load whole tables).
    @Query private var todaySpending: [SpendingLog]
    @Query private var todayImpulses: [ImpulseLog]
    @Query private var dailyRecords: [DailyRecord]
    @State private var showAddSpend = false
    @State private var showAddImpulse = false
    @State private var spendingToDelete: SpendingLog?
    @State private var impulseToDelete: ImpulseLog?
    @State private var selectedSegment: Int = {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-LogSegment"), i + 1 < a.count, let v = Int(a[i + 1]) { return v }
        #endif
        return 0
    }()
    @State private var showHeader = false
    @State private var showContent = false

    init() {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        _todaySpending = Query(filter: #Predicate<SpendingLog> { $0.date >= start && $0.date < end },
                               sort: \SpendingLog.date, order: .reverse)
        _todayImpulses = Query(filter: #Predicate<ImpulseLog> { $0.date >= start && $0.date < end },
                               sort: \ImpulseLog.date, order: .reverse)
        _dailyRecords = Query(filter: #Predicate<DailyRecord> { $0.date >= start && $0.date < end },
                              sort: \DailyRecord.date, order: .reverse)
    }

    private var totalSpentToday: Double {
        todaySpending.reduce(0) { $0 + $1.amount }
    }

    private var profile: UserProfile? { profiles.first }

    private var todayRecord: DailyRecord? { dailyRecords.first }

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
                            .font(.app(size: 24))
                            .foregroundColor(AppTheme.primaryGreen)
                    }
                    .accessibilityLabel(Text("Add entry"))
                }
            }
            .sheet(isPresented: $showAddSpend) {
                AddSpendingView()
            }
            .confirmationDialog(Text("Delete this purchase?"), isPresented: Binding(
                get: { spendingToDelete != nil }, set: { if !$0 { spendingToDelete = nil } }
            ), titleVisibility: .visible, presenting: spendingToDelete) { log in
                Button(role: .destructive) { deleteSpending(log) } label: { Text("Delete") }
                Button(role: .cancel) { spendingToDelete = nil } label: { Text("Cancel") }
            } message: { _ in
                Text("Today's totals will be updated.")
            }
            .confirmationDialog(Text("Delete this impulse?"), isPresented: Binding(
                get: { impulseToDelete != nil }, set: { if !$0 { impulseToDelete = nil } }
            ), titleVisibility: .visible, presenting: impulseToDelete) { impulse in
                Button(role: .destructive) { deleteImpulse(impulse) } label: { Text("Delete") }
                Button(role: .cancel) { impulseToDelete = nil } label: { Text("Cancel") }
            } message: { _ in
                Text("Any savings credited for it will be removed.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .spendZeroPerformAction)) { note in
                if note.object as? AppAction == .logSpending { showAddSpend = true }
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
                        .font(.app(size: 36, weight: .bold, design: .rounded))
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
                        .font(.app(size: 20, weight: .semibold, design: .rounded))
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
                        .contextMenu {
                            Button(role: .destructive) { spendingToDelete = log } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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
                        .contextMenu {
                            Button(role: .destructive) { impulseToDelete = impulse } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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
            // Intro line — these now persist, earn XP, and add to savings.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(AppTheme.primaryGreen)
                Text("Check off today's wins to earn XP & log savings")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
            }

            ForEach(WinItem.all, id: \.title) { win in
                WinChecklistRow(
                    win: win,
                    isChecked: todayRecord?.wins.contains(win.title) ?? false,
                    onToggle: { toggleWin(win) }
                )
            }
        }
    }

    private func deleteSpending(_ log: SpendingLog) {
        ProgressEngine.shared.deleteSpending(log, profile: profile, context: modelContext)
        spendingToDelete = nil
        EventPresenter.shared.enqueue(.info(String(localized: "Purchase deleted")))
    }

    private func deleteImpulse(_ impulse: ImpulseLog) {
        ProgressEngine.shared.deleteImpulse(impulse, profile: profile, context: modelContext)
        impulseToDelete = nil
        EventPresenter.shared.enqueue(.info(String(localized: "Impulse deleted")))
    }

    private func toggleWin(_ win: WinItem) {
        let outcome = ProgressEngine.shared.toggleWin(win, profile: profile, context: modelContext)
        if let outcome {
            EventPresenter.shared.present(outcome,
                                          primary: outcome.xpGranted > 0 ? .winLogged(xp: outcome.xpGranted) : nil,
                                          rank: profile?.gameProfile?.currentRank)
        } else {
            HapticManager.shared.trigger(.toggleOff)
        }
    }
}

// MARK: - Sub Views

struct SpendingLogRow: View {
    let log: SpendingLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.category.icon)
                .font(.app(size: 18))
                .foregroundColor(Color(hex: log.category.color))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(hex: log.category.color).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(log.category.rawValue))
                    .font(.app(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                if !log.note.isEmpty {
                    Text(log.note)
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("-\(log.amount.currencyFormattedDecimal)")
                    .font(.app(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.destructive)

                if log.wasImpulse {
                    Text("Impulse")
                        .font(.app(size: 9, weight: .bold))
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
                .font(.app(size: 22))
                .foregroundColor(impulse.wasResisted ? AppTheme.primaryGreen : AppTheme.destructive)

            VStack(alignment: .leading, spacing: 2) {
                Text(impulse.item)
                    .font(.app(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(LocalizedStringKey(impulse.category.rawValue))
                    .font(AppTheme.smallFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(impulse.estimatedCost.currencyFormatted)
                    .font(.app(size: 16, weight: .bold, design: .rounded))
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

struct WinChecklistRow: View {
    let win: WinItem
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onToggle()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.app(size: 22))
                    .foregroundColor(isChecked ? AppTheme.primaryGreen : AppTheme.textTertiary)

                Image(systemName: win.icon)
                    .font(.app(size: 16))
                    .foregroundColor(AppTheme.textSecondary)

                Text(win.label)
                    .font(.app(size: 15, weight: .medium))
                    .foregroundColor(isChecked ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .strikethrough(isChecked)

                Spacer()

                Text(win.saved)
                    .font(.app(size: 14, weight: .bold, design: .rounded))
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
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.app(size: 40))
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
