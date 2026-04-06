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

            ProgressChartsView()
                .tabItem {
                    Label(AppTab.charts.title, systemImage: AppTab.charts.icon)
                }
                .tag(AppTab.charts)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(AppTheme.primaryGreen)
    }
}

enum AppTab: String, CaseIterable {
    case dashboard
    case logger
    case calendar
    case charts
    case settings

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .logger: return "Log"
        case .calendar: return "Streak"
        case .charts: return "Progress"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .logger: return "plus.circle.fill"
        case .calendar: return "calendar"
        case .charts: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
