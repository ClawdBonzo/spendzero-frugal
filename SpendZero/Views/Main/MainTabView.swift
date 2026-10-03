import SwiftUI
import StoreKit
import SwiftData

extension Notification.Name {
    /// Post with an `AppTab` object to switch tabs from anywhere (quick actions, intents).
    static let spendZeroSelectTab = Notification.Name("spendZeroSelectTab")
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = AppTab.initialFromLaunchArgs
    @State private var presenter = EventPresenter.shared
    @Query private var profiles: [UserProfile]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var router = DeepLinkRouter.shared
    @State private var deepLinkedChallenge: DeepLinkedChallenge?

    /// Sheet item for a challenge-library deep link.
    struct DeepLinkedChallenge: Identifiable {
        let key: String
        var id: String { key }
    }

    var body: some View {
        ZStack {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.icon)
                }
                .tag(AppTab.dashboard)

            DailyLoggerView()
                .tabItem {
                    Label(AppTab.logger.title, systemImage: AppTab.logger.icon)
                }
                .tag(AppTab.logger)

            StreakCalendarView()
                .tabItem {
                    Label(AppTab.calendar.title, systemImage: AppTab.calendar.icon)
                }
                .tag(AppTab.calendar)

            GamificationHubView()
                .tabItem {
                    Label(AppTab.gamification.title, systemImage: AppTab.gamification.icon)
                }
                .tag(AppTab.gamification)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(AppTheme.primaryGreen)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.shared.trigger(.tabSwitch)
        }
        .onReceive(NotificationCenter.default.publisher(for: .spendZeroSelectTab)) { note in
            if let tab = note.object as? AppTab { selectedTab = tab }
        }
        .onReceive(NotificationCenter.default.publisher(for: .spendZeroPendingAction)) { _ in
            routePendingAction()
        }
        .onChange(of: router.pendingChallengeKey) { _, _ in consumeDeepLink() }
        .sheet(item: $deepLinkedChallenge) { link in
            NavigationStack {
                ChallengeLibraryView(highlightKey: link.key.isEmpty ? nil : link.key, showsDoneButton: true)
            }
        }
        .onAppear {
            consumeDeepLink()
            routePendingAction()
            #if DEBUG
            stageDebugCelebration()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { routePendingAction() }
        }
        .onChange(of: presenter.reviewRequest) { _, _ in
            // Let the last celebration finish animating out before the system sheet appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                guard scenePhase == .active else { return }
                requestReview()
                presenter.didRequestReview()
            }
        }

        // Gamification feedback, rendered once for every tab.
        VStack(spacing: 12) {
            if let toast = presenter.toast {
                GameEventToastView(event: toast.event, onDismiss: { presenter.dismissToast() })
                    .id(toast.id)
            }
            Spacer()
        }
        .padding()
        .allowsHitTesting(presenter.toast != nil)

        if let lu = presenter.levelUp {
            LevelUpCelebrationView(newLevel: lu.new, rank: lu.rank, previousLevel: lu.previous,
                                   onDismiss: { presenter.dismissLevelUp() })
        }
        if let badge = presenter.badgeUnlock {
            BadgeUnlockCelebrationView(badge: badge, onDismiss: { presenter.dismissBadge() })
        }
        if let sealed = presenter.daySealed {
            DaySealedView(info: sealed, onDismiss: {
                withAnimation(.easeOut(duration: 0.25)) { presenter.dismissDaySealed() }
            })
            .id(sealed.id)
            .transition(.opacity)
            .zIndex(10)
        }
        }
        .monthlyRecapPresenter()
    }
}

extension MainTabView {
    fileprivate func consumeDeepLink() {
        guard let key = router.pendingChallengeKey else { return }
        router.pendingChallengeKey = nil
        deepLinkedChallenge = DeepLinkedChallenge(key: key)
    }

    /// Quick actions, Siri and notification buttons queue an `AppAction`; land on the right tab
    /// and tell that tab to open its sheet.
    fileprivate func routePendingAction() {
        guard let action = AppAction.dequeue() else { return }
        switch action {
        case .logSpending:
            selectedTab = .logger
        case .logImpulse:
            selectedTab = .dashboard
        case .markNoSpendDay:
            selectedTab = .dashboard
        }
        // Let the tab switch land before the sheet presents.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .spendZeroPerformAction, object: action)
        }
    }
}

#if DEBUG
extension MainTabView {
    /// Screenshot/QA hooks: -ShowDaySealed, -ShowLevelUp, -ShowBadge.
    fileprivate func stageDebugCelebration() {
        let args = ProcessInfo.processInfo.arguments
        let presenter = EventPresenter.shared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if args.contains("-ShowDaySealed") {
                presenter.daySealed = .init(streak: 24, previousStreak: 23, xp: 150, saved: 40, lucky: false,
                                            freezeEarned: false, questsCompleted: [String(localized: "Log today as a no-spend day")],
                                            challengeCompleted: nil, totalNoSpendDays: 41)
            } else if args.contains("-ShowLevelUp") {
                presenter.levelUp = (12, 13, LevelRank(rawValue: 13) ?? .wealthKing)
            } else if args.contains("-ShowBadge") {
                presenter.badgeUnlock = BadgeInstance(badgeID: .thirtyDayStreak, rarity: .epic)
            }
        }
    }
}
#endif

extension Notification.Name {
    static let spendZeroPerformAction = Notification.Name("spendZeroPerformAction")
}

enum AppTab: String, CaseIterable {
    case dashboard
    case logger
    case calendar
    case gamification
    case settings

    var title: String {
        switch self {
        case .dashboard: return String(localized: "Dashboard")
        case .logger: return String(localized: "Log")
        case .calendar: return String(localized: "Streak")
        case .gamification: return String(localized: "Quests")
        case .settings: return String(localized: "Settings")
        }
    }

    static var initialFromLaunchArgs: AppTab {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-InitialTab"), i + 1 < a.count, let t = AppTab(rawValue: a[i + 1]) { return t }
        #endif
        return .dashboard
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .logger: return "square.and.pencil"
        case .calendar: return "flame.fill"
        case .gamification: return "star.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
