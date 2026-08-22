import UIKit
import SwiftData
import UserNotifications

/// Hosts the pieces the SwiftUI lifecycle can't: notification action buttons and Home Screen
/// quick actions. Both ultimately route through `ProgressEngine` / `AppAction`.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.registerCategories()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // MARK: Notification actions

    /// Show reminders even while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case NotificationManager.Action.markToday:
            await MainActor.run { _ = Self.markNoSpendDay(for: Date()) }
        case NotificationManager.Action.markYesterday:
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            await MainActor.run { _ = Self.markNoSpendDay(for: yesterday) }
        case NotificationManager.Action.logSpending:
            AppAction.logSpending.enqueue()
        default:
            break   // plain tap just opens the app
        }
    }

    /// Apply a mark straight to the store (works while backgrounded — the app process is
    /// launched for notification actions).
    @MainActor
    @discardableResult
    static func markNoSpendDay(for day: Date) -> IntentBridge.MarkResult {
        guard let container = SpendZeroStore.container else { return .noProfile }
        let context = container.mainContext
        guard let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first else { return .noProfile }
        let engine = ProgressEngine.shared
        if let blocker = engine.noSpendDayBlocker(profile: profile, context: context, now: day) {
            return blocker == .alreadyLogged ? .alreadyLogged : .spentToday
        }
        guard let outcome = engine.logNoSpendDay(for: day, profile: profile, context: context) else { return .spentToday }
        EventPresenter.shared.present(outcome, primary: .nospendDayRecorded(xp: outcome.xpGranted),
                                      rank: profile.gameProfile?.currentRank)
        return .marked(streak: outcome.newStreak ?? profile.currentStreak)
    }
}

/// Home Screen quick actions (long-press the app icon).
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem { handle(item) }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        handle(shortcutItem)
        completionHandler(true)
    }

    private func handle(_ item: UIApplicationShortcutItem) {
        guard let action = AppAction(rawValue: item.type) else { return }
        if action == .markNoSpendDay {
            Task { @MainActor in
                let result = AppDelegate.markNoSpendDay(for: Date())
                if case .spentToday = result { EventPresenter.shared.enqueue(.info(String(localized: "Today already has spending logged."))) }
                if case .alreadyLogged = result { EventPresenter.shared.enqueue(.info(String(localized: "Today is already logged."))) }
            }
        } else {
            action.enqueue()
        }
    }
}
