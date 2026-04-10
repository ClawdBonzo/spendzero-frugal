import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
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
        case .dashboard: return "Dashboard"
        case .logger: return "Log"
        case .calendar: return "Streak"
        case .gamification: return "Quests"
        case .settings: return "Settings"
        }
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
