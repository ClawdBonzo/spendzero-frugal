import SwiftUI
import SwiftData

extension Notification.Name {
    /// Post with an `AppTab` object to switch tabs from anywhere (quick actions, intents).
    static let spendZeroSelectTab = Notification.Name("spendZeroSelectTab")
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = AppTab.initialFromLaunchArgs
    @State private var presenter = EventPresenter.shared
    @Query private var profiles: [UserProfile]

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
        }
    }
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
