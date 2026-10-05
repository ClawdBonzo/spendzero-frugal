import SwiftUI
import SwiftData
import UIKit

/// Alternate app icons, unlocked by level: palette/material variations of the SpendZero mark.
enum AppIconOption: String, CaseIterable, Identifiable {
    case standard, gold, emerald, midnight

    var id: String { rawValue }

    /// Name passed to `setAlternateIconName` (nil = the primary icon). Must match the icon sets in
    /// Assets.xcassets and ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
    var iconName: String? {
        switch self {
        case .standard: return nil
        case .gold: return "AppIcon-Gold"
        case .emerald: return "AppIcon-Emerald"
        case .midnight: return "AppIcon-Midnight"
        }
    }

    /// Small copy of the icon for display (app icon sets can't be loaded as images).
    var preview: String {
        switch self {
        case .standard: return "AppIconPreview-Default"
        case .gold: return "AppIconPreview-Gold"
        case .emerald: return "AppIconPreview-Emerald"
        case .midnight: return "AppIconPreview-Midnight"
        }
    }

    var title: String {
        switch self {
        case .standard: return String(localized: "Classic")
        case .gold: return String(localized: "Gold")
        case .emerald: return String(localized: "Emerald")
        case .midnight: return String(localized: "Midnight")
        }
    }

    var unlockLevel: Int {
        switch self {
        case .standard: return 1
        case .gold: return 5
        case .emerald: return 10
        case .midnight: return 15
        }
    }

    var accent: Color {
        switch self {
        case .standard: return AppTheme.primaryGreen
        case .gold: return AppTheme.accentGold
        case .emerald: return Color(hex: "1DE9B6")
        case .midnight: return Color(hex: "8FA6E0")
        }
    }

    static var current: AppIconOption {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .standard
    }
}

struct AppIconPicker: View {
    @Query private var profiles: [UserProfile]
    @State private var selected: AppIconOption = .current
    @State private var errorMessage: String?
    @State private var bump = 0

    private var level: Int {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-IconLevel"), i + 1 < a.count, let l = Int(a[i + 1]) { return l }
        #endif
        return profiles.first?.gameProfile?.currentLevel ?? 1
    }

    var body: some View {
        ZStack {
            AppScreenBackground()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(AppIconOption.allCases) { option in
                            tile(option)
                        }
                    }
                    Text("Earn XP to unlock new icons. Your choice applies on the Home Screen right away.")
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(AppTheme.paddingMedium)
            }
        }
        .navigationTitle(String(localized: "App Icon"))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: bump)
        .alert(String(localized: "Couldn’t Change Icon"), isPresented: Binding(get: { errorMessage != nil },
                                                                             set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(selected.preview)
                .resizable()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: selected.accent.opacity(0.4), radius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text("Make SpendZero yours")
                    .font(AppTheme.headlineFont)
                    .foregroundColor(AppTheme.textPrimary)
                Text("You’re level \(level)")
                    .font(AppTheme.smallFont)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.paddingMedium)
        .glassCard(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    @ViewBuilder
    private func tile(_ option: AppIconOption) -> some View {
        let unlocked = level >= option.unlockLevel
        let isSelected = option == selected
        Button {
            choose(option)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Image(option.preview)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .saturation(unlocked ? 1 : 0.15)
                        .brightness(unlocked ? 0 : -0.25)
                        .shadow(color: unlocked ? option.accent.opacity(isSelected ? 0.55 : 0.2) : .clear, radius: isSelected ? 14 : 6)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.app(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                }
                .frame(maxWidth: 110)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.app(size: 24, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppTheme.background, AppTheme.primaryGreen)
                            .offset(x: 8, y: -8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(option.title)
                    .font(.app(size: 15, weight: .semibold))
                    .foregroundColor(unlocked ? AppTheme.textPrimary : AppTheme.textSecondary)

                levelBadge(option, unlocked: unlocked)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: AppTheme.cornerRadiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(isSelected ? option.accent.opacity(0.8) : Color.white.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? String(localized: "Selected")
                            : unlocked ? "" : String(localized: "Unlocks at level \(option.unlockLevel)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func levelBadge(_ option: AppIconOption, unlocked: Bool) -> some View {
        if option == .standard {
            Text("Default")
                .font(.app(size: 11, weight: .bold))
                .foregroundColor(AppTheme.textTertiary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        } else {
            HStack(spacing: 4) {
                Image(systemName: unlocked ? "star.fill" : "lock.fill")
                Text("Level \(option.unlockLevel)")
            }
            .font(.app(size: 11, weight: .bold))
            .foregroundColor(unlocked ? AppTheme.background : AppTheme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(unlocked ? option.accent : Color.white.opacity(0.08)))
        }
    }

    private func choose(_ option: AppIconOption) {
        guard option != selected, level >= option.unlockLevel else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = String(localized: "This device doesn’t support alternate app icons.")
            return
        }
        let previous = selected
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = option }
        bump += 1
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            guard let error else { return }
            DispatchQueue.main.async {
                withAnimation { selected = previous }
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { AppIconPicker() }
}
