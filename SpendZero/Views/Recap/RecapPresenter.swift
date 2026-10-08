import SwiftUI
import SwiftData

/// Presents last month's recap once, the first time the app is active on or after the 1st.
/// Attach once at the root of the tabbed UI: `.monthlyRecapPresenter()`.
/// Waits until no other celebration (day sealed, level-up, badge) is on screen.
/// DEBUG: launching with `-ShowRecap` presents a demo recap immediately (for screenshots).
struct MonthlyRecapPresenter: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var recap: MonthRecap?
    @State private var checking = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $recap) { recap in
                MonthlyRecapView(recap: recap) { self.recap = nil }
                    .presentationBackground(.clear)
            }
            .onAppear { schedule(delay: 1.2) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { schedule(delay: 1.2) }
            }
    }

    private func schedule(delay: Double) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ShowRecap") {
            guard recap == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { recap = .demo() }
            return
        }
        #endif
        guard !checking, recap == nil else { return }
        checking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            checking = false
            check()
        }
    }

    @MainActor private func check() {
        guard scenePhase == .active, recap == nil else { return }
        let events = EventPresenter.shared
        guard events.daySealed == nil, events.levelUp == nil, events.badgeUnlock == nil else {
            schedule(delay: 2)   // try again once the celebration is dismissed
            return
        }
        guard let month = RecapScheduler.pendingMonth(now: Date(), context: context) else { return }
        // Mark first: a recap that is closed early (or crashes) never nags again.
        RecapScheduler.markShown(month: month)
        recap = RecapBuilder.load(month: month, context: context)
    }
}

extension View {
    /// Shows the Monthly Recap story when last month's recap becomes available.
    func monthlyRecapPresenter() -> some View { modifier(MonthlyRecapPresenter()) }
}
