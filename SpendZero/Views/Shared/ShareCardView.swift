import SwiftUI

// MARK: - Streak Share Card
// A 9:16 story card in the same minted-gold language as the Day Sealed card: the seal medallion,
// the streak, the total kept and a small wealth-tree silhouette. In-app (`live`) the gold follows
// the phone's tilt; the exported image (ImageRenderer @3×, 1080×1920) is the static version.

struct StreakShareCard: View {
    let streak: Int
    let name: String
    let totalSaved: Double
    /// Animated gold sheen for on-screen previews; off for image rendering.
    var live: Bool = false

    static let size = CGSize(width: 360, height: 640)

    private var today: String { Date().formatted(.dateTime.month(.abbreviated).day()) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "04140D"), Color(hex: "0A2A1C"), Color(hex: "04140D")],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [AppTheme.accentGold.opacity(0.3), .clear],
                           center: UnitPoint(x: 0.5, y: 0.3), startRadius: 10, endRadius: 270)
            RadialGradient(colors: [AppTheme.primaryGreen.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.5, y: 1), startRadius: 10, endRadius: 300)
            ShareRays()
                .opacity(0.55)
                .frame(width: 600, height: 600)
                .position(x: Self.size.width / 2, y: 196)

            VStack(spacing: 0) {
                Text(eyebrow)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(Color(hex: "7FD9A8"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 44)

                medallion
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
                    .padding(.top, 22)

                Text(streak.formatted())
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, AppTheme.accentGold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: AppTheme.accentGold.opacity(0.3), radius: 14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 10)
                Text(streak == 1 ? String(localized: "day without spending") : String(localized: "days in a row without spending"))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if totalSaved > 0 {
                    HStack(spacing: 6) {
                        Text(totalSaved.currencyFormatted)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.primaryGreen)
                        Text(String(localized: "kept, not spent"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(AppTheme.primaryGreen.opacity(0.12)))
                    .overlay(Capsule().stroke(AppTheme.primaryGreen.opacity(0.35), lineWidth: 1))
                    .padding(.top, 16)
                }

                Spacer(minLength: 8)

                TreeSilhouette(growth: min(1, 0.35 + Double(streak) / 60))
                    .frame(width: 120, height: 92)

                HStack(spacing: 8) {
                    Image("BrandIcon").resizable().frame(width: 26, height: 26).clipShape(RoundedRectangle(cornerRadius: 7))
                    Text(verbatim: "SpendZero · No Spend Challenge")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(RoundedRectangle(cornerRadius: live ? 28 : 0, style: .continuous))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(streak)-day no-spend streak, \(totalSaved.currencyFormatted) kept"))
    }

    private var eyebrow: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "No-spend streak").uppercased(with: .current)
                               : String(localized: "\(trimmed)'s no-spend streak").uppercased(with: .current)
    }

    @ViewBuilder private var medallion: some View {
        let coin = SealMedallion(ringText: String(localized: "NO-SPEND DAY"), caption: today)
        if live { coin.goldSheen() } else { coin }
    }

    /// Renders the static card at 3× for sharing.
    @MainActor
    static func render(streak: Int, name: String, totalSaved: Double) -> UIImage? {
        let renderer = ImageRenderer(content: StreakShareCard(streak: streak, name: name, totalSaved: totalSaved))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Static rays behind the medallion (the animated Sunburst can't be captured mid-spin).
private struct ShareRays: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let rays = 20
            let step = 2 * Double.pi / Double(rays)
            let r = min(size.width, size.height) / 2
            for i in 0..<rays {
                let a = Double(i) * step
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + cos(a - step * 0.22) * r, y: c.y + sin(a - step * 0.22) * r))
                p.addLine(to: CGPoint(x: c.x + cos(a + step * 0.22) * r, y: c.y + sin(a + step * 0.22) * r))
                p.closeSubpath()
                ctx.fill(p, with: .radialGradient(Gradient(colors: [AppTheme.accentGold.opacity(0.3), AppTheme.accentGold.opacity(0)]),
                                                  center: c, startRadius: 0, endRadius: r))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small, flat wealth tree: trunk, forked branches, a layered canopy and a few gold coins.
/// `growth` (0…1) fills out the canopy.
struct TreeSilhouette: View {
    var growth: Double = 0.6

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let g = CGFloat(max(0.2, min(1, growth)))
            let base = CGPoint(x: w / 2, y: h * 0.97)
            let crown = CGPoint(x: w / 2, y: h * 0.42)

            // Ground line.
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.93, width: w * 0.64, height: h * 0.08)),
                     with: .color(AppTheme.primaryGreen.opacity(0.18)))

            // Trunk and two branches.
            var trunk = Path()
            trunk.move(to: CGPoint(x: base.x - w * 0.05, y: base.y))
            trunk.addQuadCurve(to: CGPoint(x: crown.x - w * 0.015, y: crown.y + h * 0.12), control: CGPoint(x: base.x - w * 0.02, y: h * 0.7))
            trunk.addLine(to: CGPoint(x: crown.x + w * 0.015, y: crown.y + h * 0.12))
            trunk.addQuadCurve(to: CGPoint(x: base.x + w * 0.05, y: base.y), control: CGPoint(x: base.x + w * 0.02, y: h * 0.7))
            trunk.closeSubpath()
            let bark = GraphicsContext.Shading.linearGradient(Gradient(colors: [Color(hex: "C9A24A"), Color(hex: "8A6A2A")]),
                                                              startPoint: CGPoint(x: 0, y: crown.y), endPoint: CGPoint(x: 0, y: base.y))
            ctx.fill(trunk, with: bark)
            for side in [-1.0, 1.0] {
                var b = Path()
                b.move(to: CGPoint(x: w / 2, y: h * 0.66))
                b.addQuadCurve(to: CGPoint(x: w / 2 + CGFloat(side) * w * 0.22 * g, y: h * 0.42),
                               control: CGPoint(x: w / 2 + CGFloat(side) * w * 0.1, y: h * 0.62))
                ctx.stroke(b, with: bark, style: StrokeStyle(lineWidth: max(2, w * 0.035), lineCap: .round))
            }

            // Canopy: overlapping discs, back layer darker.
            let blobs: [(CGFloat, CGFloat, CGFloat)] = [
                (0, -0.16, 0.24), (-0.2, -0.04, 0.19), (0.2, -0.04, 0.19),
                (-0.1, -0.24, 0.17), (0.11, -0.25, 0.17), (-0.3, 0.06, 0.13), (0.3, 0.06, 0.13),
            ]
            for (pass, color) in [(0, Color(hex: "0B6B3A")), (1, AppTheme.primaryGreen)] {
                for (i, b) in blobs.enumerated() where Double(i) < 3 + 4 * Double(g) {
                    let r = b.2 * w * (pass == 0 ? 1.08 : 0.94) * (0.75 + 0.25 * g)
                    let c = CGPoint(x: crown.x + b.0 * w * g, y: crown.y + b.1 * h + (pass == 0 ? 2 : 0))
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                             with: pass == 0 ? .color(color) : .radialGradient(
                                Gradient(colors: [Color(hex: "B9F6CA"), color, Color(hex: "00A152")]),
                                center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.3))
                }
            }

            // Gold coins in the canopy.
            for (x, y) in [(-0.17, -0.02), (0.15, -0.12), (0.02, 0.04), (-0.04, -0.27), (0.24, 0.08)].prefix(2 + Int(3 * g)) {
                let r = w * 0.045
                let c = CGPoint(x: crown.x + x * w, y: crown.y + y * h)
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [Color(hex: "FFF3B0"), Color(hex: "FFC400"), Color(hex: "B8860B")]),
                    center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.35), startRadius: 0, endRadius: r * 1.4))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Share Button

struct ShareStreakButton: View {
    let streak: Int
    let name: String
    let totalSaved: Double

    @State private var showPreview = false

    var body: some View {
        Button {
            HapticManager.shared.trigger(.buttonTap)
            showPreview = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.app(size: 13, weight: .semibold))
                Text("Share")
                    .font(.app(size: 13, weight: .semibold))
            }
            .foregroundColor(AppTheme.primaryGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.primaryGreen.opacity(0.12))
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showPreview) {
            StreakSharePreview(streak: streak, name: name, totalSaved: totalSaved)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.background)
        }
        .accessibilityLabel("Share your \(streak)-day streak")
    }
}

/// The card as it will look, live (tilt the phone to catch the light), with the share action.
struct StreakSharePreview: View {
    let streak: Int
    let name: String
    let totalSaved: Double

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { geo in
                let scale = min(geo.size.width / StreakShareCard.size.width, geo.size.height / StreakShareCard.size.height)
                StreakShareCard(streak: streak, name: name, totalSaved: totalSaved, live: true)
                    .scaleEffect(scale * (appeared ? 1 : 0.94))
                    .opacity(appeared ? 1 : 0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .shadow(color: AppTheme.accentGold.opacity(0.18), radius: 30, y: 12)
            }
            .padding(.top, 28)

            HStack(spacing: 12) {
                if let image {
                    let shareable = Image(uiImage: image)
                    ShareLink(item: shareable,
                              preview: SharePreview(String(localized: "My no-spend streak"), image: shareable)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.app(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "1A1200"))
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(RoundedRectangle(cornerRadius: 18).fill(AppTheme.accentGold))
                    }
                }
                Button { dismiss() } label: {
                    Text("Done")
                        .font(.app(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 54)
                        .background(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.22), lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear {
            image = StreakShareCard.render(streak: streak, name: name, totalSaved: totalSaved)
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) { appeared = true }
        }
    }
}

// MARK: - Achievement Share Button
// Lightweight share prompt for high-emotion moments (level-up, badge unlock) — the
// exact moment users want to brag. Shares a short text brag + App Store nudge.

struct AchievementShareButton: View {
    let message: String
    var tint: Color = AppTheme.primaryGreen

    @State private var showSheet = false

    var body: some View {
        Button {
            HapticManager.shared.trigger(.buttonTap)
            showSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.app(size: 14, weight: .semibold))
                Text("Share your win")
                    .font(.app(size: 15, weight: .semibold))
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .sheet(isPresented: $showSheet) {
            ShareSheetView(items: [message])
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview("Streak share card") {
    StreakShareCard(streak: 23, name: "Alex", totalSaved: 2847, live: true)
}
