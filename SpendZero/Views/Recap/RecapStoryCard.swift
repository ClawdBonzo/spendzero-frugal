import SwiftUI

/// The 9:16 summary image exported by "Share to Stories". Static (no timelines or shaders) so
/// ImageRenderer captures it exactly; no names or notes, only the month's totals.
struct RecapStoryCard: View {
    let recap: MonthRecap

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "04140D"), Color(hex: "0A2A1C"), Color(hex: "071A12")],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [AppTheme.accentGold.opacity(0.24), .clear],
                           center: UnitPoint(x: 0.35, y: 0.3), startRadius: 10, endRadius: 300)
            RadialGradient(colors: [AppTheme.primaryGreen.opacity(0.12), .clear],
                           center: UnitPoint(x: 0.9, y: 0.85), startRadius: 10, endRadius: 260)

            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "SpendZero · \(recap.monthName) recap").uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(RecapStyle.eyebrow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(String(localized: "Your \(recap.monthName), sealed."))
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 10)

                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(recap.noSpendDays.formatted())
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundStyle(RecapStyle.goldText)
                        .shadow(color: AppTheme.accentGold.opacity(0.35), radius: 16)
                    Text(recap.noSpendDays == 1 ? String(localized: "no-spend\nday") : String(localized: "no-spend\ndays"))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.bottom, 18)
                }

                RecapCoinCalendar(recap: recap, spacing: 6, animated: false)
                    .frame(width: 250)
                    .padding(.top, 2)

                Spacer(minLength: 16)

                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        tile(recap.moneyKept.currencyFormatted, String(localized: "kept, not spent"), AppTheme.primaryGreen)
                        tile(recap.bestStreak == 1 ? String(localized: "1 day") : String(localized: "\(recap.bestStreak) days"),
                             String(localized: "best streak"), .white)
                    }
                    GridRow {
                        tile(recap.urgesBeaten.formatted(), String(localized: "urges beaten"), .white)
                        tile(String(localized: "Level \(recap.levelEnd)"),
                             recap.levelsGained == 0 ? String(localized: "your tree held strong")
                                : recap.levelsGained == 1 ? String(localized: "your tree grew 1 level")
                                : String(localized: "your tree grew \(recap.levelsGained) levels"),
                             AppTheme.accentGold)
                    }
                }

                HStack(spacing: 8) {
                    Image("BrandIcon").resizable().frame(width: 26, height: 26).clipShape(RoundedRectangle(cornerRadius: 7))
                    Text(verbatim: "SpendZero · No Spend Challenge")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
            }
            .padding(.horizontal, 26)
            .padding(.top, 44)
            .padding(.bottom, 30)
        }
        .frame(width: 360, height: 640)
        .environment(\.colorScheme, .dark)
    }

    private func tile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(RecapStyle.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    /// Rendered at 3× (1080×1920) for Instagram/TikTok stories.
    @MainActor
    static func render(_ recap: MonthRecap) -> Image? {
        let renderer = ImageRenderer(content: RecapStoryCard(recap: recap))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
