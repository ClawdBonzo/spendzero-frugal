import SwiftUI

/// Everything of the jar that sits behind the coins: the glow and the back of the glass.
struct JarGlassBack: View {
    let geometry: JarGeometry
    /// 0…1, how full the jar is; warms the glow.
    var fill: Double
    var pulse: Bool

    var body: some View {
        let g = geometry
        ZStack {
            // Soft gold bloom behind the jar, stronger as it fills, flaring when a coin lands.
            RadialGradient(colors: [AppTheme.accentGold.opacity(0.10 + 0.16 * fill + (pulse ? 0.14 : 0)),
                                    AppTheme.accentGold.opacity(0)],
                           center: .center, startRadius: 0, endRadius: g.jarRect.width * 0.85)
                .frame(width: g.jarRect.width * 1.9, height: g.jarRect.width * 1.9)
                .scaleEffect(pulse ? 1.08 : 1)
                .position(x: g.jarRect.midX, y: g.jarRect.midY + g.jarRect.height * 0.06)

            Canvas { ctx, _ in
                let outer = g.outerPath
                // Tinted glass body.
                ctx.fill(outer, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.055), .white.opacity(0.018)]),
                    startPoint: CGPoint(x: 0, y: g.jarRect.minY), endPoint: CGPoint(x: 0, y: g.jarRect.maxY)))
                // The far wall curving away on the right.
                ctx.fill(outer, with: .linearGradient(
                    Gradient(colors: [.clear, .clear, .black.opacity(0.22)]),
                    startPoint: CGPoint(x: g.jarRect.minX, y: 0), endPoint: CGPoint(x: g.jarRect.maxX, y: 0)))
                // Back rim of the base, seen through the glass.
                let base = CGRect(x: g.jarRect.minX + g.jarRect.width * 0.12, y: g.jarRect.maxY - 16,
                                  width: g.jarRect.width * 0.76, height: 12)
                ctx.stroke(Path(ellipseIn: base), with: .color(.white.opacity(0.05)), lineWidth: 1)
            }
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }
}

/// Everything in front of the coins: glass edges, reflections, the lid and its coin slot.
struct JarGlassFront: View {
    let geometry: JarGeometry
    var fill: Double

    var body: some View {
        let g = geometry
        Canvas { ctx, _ in
            let jar = g.jarRect
            let outer = g.outerPath

            // Warm light from the gold bouncing around the bottom of the glass.
            if fill > 0 {
                var warm = ctx
                warm.blendMode = .plusLighter
                warm.clip(to: outer)
                let top = jar.maxY - jar.height * (0.15 + 0.7 * fill)
                warm.fill(outer, with: .linearGradient(
                    Gradient(colors: [AppTheme.accentGold.opacity(0), AppTheme.accentGold.opacity(0.07 + 0.05 * fill)]),
                    startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: jar.maxY)))
            }

            // Inner wall (glass thickness) and the outer edge, brighter where light grazes the curve.
            ctx.stroke(g.innerPath, with: .color(.white.opacity(0.07)), lineWidth: 1)
            ctx.stroke(outer, with: .linearGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.34), location: 0),
                    .init(color: .white.opacity(0.12), location: 0.3),
                    .init(color: .white.opacity(0.07), location: 0.6),
                    .init(color: .white.opacity(0.26), location: 1)
                ]),
                startPoint: CGPoint(x: jar.minX, y: 0), endPoint: CGPoint(x: jar.maxX, y: 0)),
                style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

            // Long highlight streak down the left side, and a thinner companion.
            let streakTop = g.shoulderBottom + 6
            let streakBottom = jar.maxY - jar.height * 0.26
            let streak = CGRect(x: jar.minX + 12, y: streakTop, width: 10, height: streakBottom - streakTop)
            ctx.fill(Path(roundedRect: streak, cornerRadius: 5), with: .linearGradient(
                Gradient(colors: [.white.opacity(0.30), .white.opacity(0.10), .white.opacity(0)]),
                startPoint: CGPoint(x: 0, y: streak.minY), endPoint: CGPoint(x: 0, y: streak.maxY)))
            let thin = CGRect(x: jar.minX + 27, y: streakTop + 10, width: 3, height: (streakBottom - streakTop) * 0.55)
            ctx.fill(Path(roundedRect: thin, cornerRadius: 1.5), with: .linearGradient(
                Gradient(colors: [.white.opacity(0.16), .white.opacity(0)]),
                startPoint: CGPoint(x: 0, y: thin.minY), endPoint: CGPoint(x: 0, y: thin.maxY)))
            // Right-edge reflection.
            let right = CGRect(x: jar.maxX - 13, y: g.shoulderBottom + 24, width: 4, height: jar.height * 0.42)
            ctx.fill(Path(roundedRect: right, cornerRadius: 2), with: .linearGradient(
                Gradient(colors: [.white.opacity(0), .white.opacity(0.13), .white.opacity(0)]),
                startPoint: CGPoint(x: 0, y: right.minY), endPoint: CGPoint(x: 0, y: right.maxY)))
            // Glint on the left shoulder.
            var shoulder = Path()
            shoulder.move(to: CGPoint(x: jar.midX - g.neckWidth / 2 - 4, y: jar.minY + 22))
            shoulder.addQuadCurve(to: CGPoint(x: jar.minX + 8, y: g.shoulderBottom + 4),
                                  control: CGPoint(x: jar.minX + 12, y: jar.minY + 24))
            ctx.stroke(shoulder, with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            // Thick glass base catching the light.
            var base = Path()
            base.addArc(center: CGPoint(x: jar.midX, y: jar.maxY - jar.width * 0.9), radius: jar.width * 0.86,
                        startAngle: .degrees(64), endAngle: .degrees(116), clockwise: false)
            ctx.stroke(base, with: .color(.white.opacity(0.10)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            // Neck lip under the lid.
            let lip = CGRect(x: jar.midX - g.neckWidth / 2 - 3, y: g.lidRect.maxY - 2, width: g.neckWidth + 6, height: 7)
            ctx.fill(Path(roundedRect: lip, cornerRadius: 3.5), with: .color(.white.opacity(0.07)))
            ctx.stroke(Path(roundedRect: lip, cornerRadius: 3.5), with: .color(.white.opacity(0.22)), lineWidth: 1)

            // Lid: brushed gunmetal band with ridges and a lit top edge.
            let lid = g.lidRect
            let lidShape = Path(roundedRect: lid, cornerRadius: 6)
            ctx.fill(lidShape, with: .linearGradient(
                Gradient(colors: [Color(hex: "4A5568"), Color(hex: "2A3444"), Color(hex: "161C27")]),
                startPoint: CGPoint(x: 0, y: lid.minY), endPoint: CGPoint(x: 0, y: lid.maxY)))
            var ridges = ctx
            ridges.clip(to: lidShape)
            var x = lid.minX + 5
            while x < lid.maxX - 3 {
                ridges.fill(Path(CGRect(x: x, y: lid.minY + 6, width: 1, height: lid.height - 8)), with: .color(.white.opacity(0.06)))
                x += 4
            }
            ctx.stroke(lidShape, with: .color(.white.opacity(0.16)), lineWidth: 1)
            var top = Path()
            top.move(to: CGPoint(x: lid.minX + 6, y: lid.minY + 1))
            top.addLine(to: CGPoint(x: lid.maxX - 6, y: lid.minY + 1))
            ctx.stroke(top, with: .color(.white.opacity(0.35)), lineWidth: 1)
            // Coin slot on the top face.
            let slot = CGRect(x: lid.midX - g.coinRadius * 1.25, y: lid.minY + 2.5, width: g.coinRadius * 2.5, height: 4)
            ctx.fill(Path(roundedRect: slot, cornerRadius: 2), with: .color(Color(hex: "05070A")))
            ctx.stroke(Path(roundedRect: slot.offsetBy(dx: 0, dy: 0.8), cornerRadius: 2),
                       with: .color(AppTheme.accentGold.opacity(0.25)), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small cast gold ingot: what a full jar becomes.
struct GoldBar: View {
    var width: CGFloat = 30

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let inset = w * 0.16
            var top = Path()
            top.move(to: CGPoint(x: inset, y: 0))
            top.addLine(to: CGPoint(x: w - inset, y: 0))
            top.addLine(to: CGPoint(x: w - inset * 0.55, y: h * 0.38))
            top.addLine(to: CGPoint(x: inset * 0.55, y: h * 0.38))
            top.closeSubpath()
            var front = Path()
            front.move(to: CGPoint(x: inset * 0.55, y: h * 0.38))
            front.addLine(to: CGPoint(x: w - inset * 0.55, y: h * 0.38))
            front.addLine(to: CGPoint(x: w, y: h))
            front.addLine(to: CGPoint(x: 0, y: h))
            front.closeSubpath()
            ctx.fill(front, with: .linearGradient(
                Gradient(colors: [Color(hex: "FFD54F"), Color(hex: "E09A00"), Color(hex: "8A5A00")]),
                startPoint: CGPoint(x: 0, y: h * 0.38), endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(top, with: .linearGradient(
                Gradient(colors: [Color(hex: "FFF6CC"), Color(hex: "FFC83D")]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.38)))
            ctx.stroke(top, with: .color(Color(hex: "FFF6CC").opacity(0.8)), lineWidth: 0.6)
        }
        .frame(width: width, height: width * 0.5)
        .shadow(color: AppTheme.accentGold.opacity(0.35), radius: 4)
        .accessibilityHidden(true)
    }
}
