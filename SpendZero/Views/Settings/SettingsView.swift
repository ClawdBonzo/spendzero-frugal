import SwiftUI
import StoreKit
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showPaywall = false
    @State private var showRedeemCode = false
    @State private var subscription = SubscriptionService.shared
    @State private var infoAlert: InfoAlert?

    private struct InfoAlert: Identifiable { let id = UUID(); let title: String; let message: String }

    private static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
    @State private var showExport = false
    @State private var showResetConfirmation = false
    @AppStorage("impulseAlertsEnabled") private var impulseAlertsEnabled = false
    @AppStorage("impulseAlertHour") private var impulseAlertHour = 18
    @State private var showNotificationDeniedAlert = false
    /// Same key and default as `SoundEffects.isEnabled`.
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage(LiveActivityCoordinator.enabledKey) private var eveningCountdownEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    /// GW Labs apps not on this iPhone yet (More from GW Labs). Rechecked whenever SpendZero comes back.
    @State private var promotedApps: [CrossPromoApp] = []

    private var profile: UserProfile? { profiles.first }

    private var impulseAlertTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: impulseAlertHour, minute: 0, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                impulseAlertHour = Calendar.current.component(.hour, from: newDate)
                if impulseAlertsEnabled {
                    NotificationManager.shared.scheduleDailyReminder(hour: impulseAlertHour)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppScreenBackground()

                List {
                    // Profile Section
                    Section {
                        HStack(spacing: 14) {
                            Image("BrandIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile?.displayName ?? String(localized: "User"))
                                    .font(.app(size: 18, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text("Member since \(profile?.createdAt ?? Date(), format: .dateTime.month(.abbreviated).year())")
                                    .font(AppTheme.smallFont)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    }

                    // Stats Section
                    Section("Your Stats") {
                        SettingsRow(icon: "flame.fill", title: "Current Streak", value: String(localized: "\(profile?.currentStreak ?? 0) days"), color: AppTheme.accentGold)
                        SettingsRow(icon: "trophy.fill", title: "Longest Streak", value: String(localized: "\(profile?.longestStreak ?? 0) days"), color: AppTheme.primaryGreen)
                        SettingsRow(icon: "banknote.fill", title: "Total Saved", value: (profile?.totalSaved ?? 0).currencyFormatted, color: AppTheme.primaryGreen)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Budget Section
                    Section("Budget") {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(AppTheme.primaryGreen)
                            Text("Daily Budget")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text((profile?.dailyBudget ?? 50).currencyFormatted)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        if let profile {
                            Slider(
                                value: Binding(
                                    get: { profile.dailyBudget },
                                    set: { profile.dailyBudget = $0; try? modelContext.save() }
                                ),
                                in: 10...200,
                                step: 5
                            )
                            .tint(AppTheme.primaryGreen)
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Premium Section
                    Section("Premium") {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(AppTheme.accentGold)
                                Text(subscription.isPremium ? "Premium Active" : "Upgrade to Premium")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                if !subscription.isPremium {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                            }
                        }

                        Button {
                            Task {
                                switch await subscription.restorePurchases() {
                                case .restored:
                                    infoAlert = InfoAlert(title: String(localized: "Purchases Restored"),
                                                          message: String(localized: "Premium is active on this device."))
                                case .nothingToRestore:
                                    infoAlert = InfoAlert(title: String(localized: "Nothing to Restore"),
                                                          message: String(localized: "No active SpendZero purchase was found for this Apple ID."))
                                case .failed(let message):
                                    infoAlert = InfoAlert(title: String(localized: "Restore Failed"), message: message)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(AppTheme.info)
                                Text("Restore Purchases")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        if !subscription.isPremium {
                            Button {
                                showRedeemCode = true
                            } label: {
                                HStack {
                                    Image(systemName: "ticket.fill")
                                        .foregroundColor(AppTheme.accentGold)
                                    Text("Redeem Code")
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }
                            .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
                                Task { await subscription.refreshAfterCodeRedemption() }
                            }
                        }

                        if subscription.isPremium {
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                HStack {
                                    Image(systemName: "creditcard")
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text("Manage Subscription")
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                            }
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Impulse Alerts Section
                    Section("Impulse Alerts") {
                        Toggle(isOn: Binding(
                            get: { impulseAlertsEnabled },
                            set: { newValue in
                                if newValue {
                                    Task {
                                        let granted = await NotificationManager.shared.requestAuthorization()
                                        if granted {
                                            impulseAlertsEnabled = true
                                            NotificationManager.shared.scheduleDailyReminder(hour: impulseAlertHour)
                                        } else {
                                            impulseAlertsEnabled = false
                                            showNotificationDeniedAlert = true
                                        }
                                    }
                                } else {
                                    impulseAlertsEnabled = false
                                    NotificationManager.shared.cancelReminder()
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(AppTheme.accentGold)
                                Text("Daily impulse reminder")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                        .tint(AppTheme.primaryGreen)

                        if impulseAlertsEnabled {
                            DatePicker(
                                selection: impulseAlertTime,
                                displayedComponents: .hourAndMinute
                            ) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(AppTheme.info)
                                    Text("Reminder time")
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Evening check-in: the Lock Screen / Dynamic Island countdown
                    Section {
                        Toggle(isOn: Binding(
                            get: { eveningCountdownEnabled },
                            set: { newValue in
                                eveningCountdownEnabled = newValue
                                LiveActivityCoordinator.shared.refresh(profile: profile, context: modelContext)
                            }
                        )) {
                            HStack {
                                Image(systemName: "hourglass")
                                    .foregroundColor(AppTheme.accentGold)
                                Text("Evening countdown")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                        .tint(AppTheme.primaryGreen)
                    } header: {
                        Text("Evening check-in")
                    } footer: {
                        Text("In the evening, shows how long you have left to seal today on the Lock Screen and in the Dynamic Island. Needs notifications.")
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Personalize: app icon + sound
                    Section("Personalize") {
                        NavigationLink {
                            AppIconPicker()
                        } label: {
                            HStack {
                                Image(systemName: "app.badge.fill")
                                    .foregroundColor(AppTheme.accentGold)
                                Text("App Icon")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { soundEffectsEnabled },
                            set: { newValue in
                                soundEffectsEnabled = newValue
                                if newValue { SoundEffects.play(.clink, volume: 0.4) }
                            }
                        )) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(AppTheme.info)
                                Text("Sound effects")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                        .tint(AppTheme.primaryGreen)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Tools Section
                    Section("Tools") {
                        NavigationLink {
                            ExportView()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(AppTheme.info)
                                Text("Export PDF Report")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        NavigationLink {
                            ChallengeLibraryView()
                        } label: {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(AppTheme.accentGold)
                                Text("Challenge Library")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Other GW Labs apps (4+ only), hidden once installed
                    if !promotedApps.isEmpty {
                        Section("More from GW Labs") {
                            ForEach(promotedApps) { app in
                                CrossPromoRow(app: app)
                            }
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    }

                    // Data Section
                    Section("Data") {
                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(AppTheme.destructive)
                                Text("Reset All Data")
                                    .foregroundColor(AppTheme.destructive)
                            }
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // About
                    Section("About") {
                        Link(destination: URL(string: "https://apps.apple.com/app/id6761767438?action=write-review")!) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(AppTheme.accentGold)
                                Text("Rate SpendZero")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }

                        HStack {
                            Text("Version")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text(Self.versionString)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                            HStack {
                                Text("Terms of Use")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }

                        Link(destination: URL(string: "https://gwlabs.app/privacy")!) {
                            HStack {
                                Text("Privacy Policy")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }

                        HStack {
                            Text("All data stored locally")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(AppTheme.primaryGreen)
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { promotedApps = CrossPromoApp.notInstalled }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { promotedApps = CrossPromoApp.notInstalled }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(onContinue: { showPaywall = false }, urgencyMessage: "Upgrade to unlock all features")
            }
            .alert(infoAlert?.title ?? "", isPresented: infoAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(infoAlert?.message ?? "")
            }
            .alert("Reset All Data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will permanently delete all your data including streaks, savings, and challenge progress. This cannot be undone.")
            }
            .alert("Notifications Off", isPresented: $showNotificationDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable notifications for SpendZero in Settings to receive impulse-purchase reminders.")
            }
        }
    }

    private var infoAlertBinding: Binding<Bool> {
        Binding(get: { infoAlert != nil }, set: { if !$0 { infoAlert = nil } })
    }

    private func resetAllData() {
        ProgressEngine.shared.resetAllData(profile: profile, context: modelContext)
        HapticManager.shared.trigger(.warning)
        EventPresenter.shared.enqueue(.info(String(localized: "All data reset")))
    }
}

struct SettingsRow: View {
    let icon: String
    let title: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.app(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }
}
