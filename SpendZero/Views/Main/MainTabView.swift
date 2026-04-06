import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label {
                        Text(AppTab.dashboard.title)
                    } icon: {
                        Image(AppTab.dashboard.assetIcon)
                            .renderingMode(.template)
                    }
                }
                .tag(AppTab.dashboard)

            DailyLoggerView()
                .tabItem {
                    Label {
                        Text(AppTab.logger.title)
                    } icon: {
                        Image(AppTab.logger.assetIcon)
                            .renderingMode(.template)
                    }
                }
                .tag(AppTab.logger)

            StreakCalendarView()
                .tabItem {
                    Label {
                        Text(AppTab.calendar.title)
                    } icon: {
                        Image(AppTab.calendar.assetIcon)
                            .renderingMode(.template)
                    }
                }
                .tag(AppTab.calendar)

            ProgressChartsView()
                .tabItem {
                    Label {
                        Text(AppTab.charts.title)
                    } icon: {
                        Image(AppTab.charts.assetIcon)
                            .renderingMode(.template)
                    }
                }
                .tag(AppTab.charts)

            SettingsView()
                .tabItem {
                    Label {
                        Text(AppTab.settings.title)
                    } icon: {
                        Image(AppTab.settings.assetIcon)
                            .renderingMode(.template)
                    }
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

    var assetIcon: String {
        switch self {
        case .dashboard: return "Tab-Dashboard"
        case .logger: return "Tab-DailyLogger"
        case .calendar: return "Tab-Challenges"
        case .charts: return "Tab-Progress"
        case .settings: return "Tab-Settings"
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
