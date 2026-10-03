import SwiftUI
import SpriteKit

/// The vault's coin, drawn once in SwiftUI and baked into SpriteKit textures. Every coin in the
/// jar shares one texture, so a full jar is a single batched draw.
struct VaultCoinFace: View {
    /// Coin diameter in points; the view itself is `diameter * VaultArt.padding` to hold the shadow.
    var diameter: CGFloat
    var shadow = true

    var body: some View {
        Canvas { ctx, size in
            let r = diameter / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2 - r * 0.04)
            let disc = CGRect(x: c.x - r, y: c.y - r, width: diameter, height: diameter)

            if shadow {
                // Soft contact shadow, baked below the coin (coins never rotate, so it stays down).
                var s = ctx
                s.addFilter(.blur(radius: r * 0.12))
                s.fill(Path(ellipseIn: disc.offsetBy(dx: 0, dy: r * 0.12)), with: .color(.black.opacity(0.55)))
            }

            // Body: a warm radial gradient lit from the top left.
            ctx.fill(Path(ellipseIn: disc), with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hex: "FFF3B4"), location: 0),
                    .init(color: Color(hex: "FFC83D"), location: 0.38),
                    .init(color: Color(hex: "D98E04"), location: 0.74),
                    .init(color: Color(hex: "8A5A00"), location: 1)
                ]),
                center: CGPoint(x: c.x - r * 0.38, y: c.y - r * 0.42), startRadius: 0, endRadius: r * 1.75))

            // Reeded edge.
            let teeth = 44
            for i in 0..<teeth {
                let a = Double(i) / Double(teeth) * 2 * .pi
                var tick = Path()
                tick.move(to: CGPoint(x: c.x + cos(a) * r * 0.87, y: c.y + sin(a) * r * 0.87))
                tick.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.985, y: c.y + sin(a) * r * 0.985))
                ctx.stroke(tick, with: .color(Color(hex: "6E4500").opacity(0.5)), lineWidth: max(0.5, r * 0.055))
            }
            ctx.stroke(Path(ellipseIn: disc.insetBy(dx: r * 0.02, dy: r * 0.02)),
                       with: .color(Color(hex: "7A4E00").opacity(0.7)), lineWidth: max(0.5, r * 0.05))

            // Raised rim and a recessed inner field.
            ctx.stroke(Path(ellipseIn: disc.insetBy(dx: r * 0.15, dy: r * 0.15)),
                       with: .color(Color(hex: "FFF1B8").opacity(0.85)), lineWidth: max(0.6, r * 0.07))
            let field = disc.insetBy(dx: r * 0.24, dy: r * 0.24)
            ctx.fill(Path(ellipseIn: field), with: .radialGradient(
                Gradient(colors: [Color(hex: "FFE07A"), Color(hex: "E7A51C"), Color(hex: "B87800")]),
                center: CGPoint(x: c.x - r * 0.25, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.1))
            ctx.stroke(Path(ellipseIn: field), with: .color(Color(hex: "7A4E00").opacity(0.55)),
                       lineWidth: max(0.5, r * 0.045))

            // Embossed zero: the SpendZero mark, with a lit upper edge and shaded lower edge.
            let mark = Text("0").font(.system(size: r * 0.95, weight: .black, design: .rounded))
            ctx.draw(mark.foregroundColor(Color(hex: "6E4500").opacity(0.55)), at: CGPoint(x: c.x + r * 0.04, y: c.y + r * 0.06))
            ctx.draw(mark.foregroundColor(Color(hex: "FFF6CC").opacity(0.9)), at: CGPoint(x: c.x - r * 0.03, y: c.y - r * 0.04))
            ctx.draw(mark.foregroundColor(Color(hex: "E9AE2A")), at: c)

            // Specular arc on the upper-left rim.
            var glint = Path()
            glint.addArc(center: c, radius: r * 0.9, startAngle: .degrees(196), endAngle: .degrees(258), clockwise: false)
            ctx.stroke(glint, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: max(0.6, r * 0.07), lineCap: .round))
        }
        .frame(width: diameter * VaultArt.padding, height: diameter * VaultArt.padding)
    }
}

@MainActor
enum VaultArt {
    /// Coin textures are drawn this much larger than the coin to hold the baked shadow.
    static let padding: CGFloat = 1.3

    private static var coinCache: [Int: SKTexture] = [:]
    private static var glowCache: SKTexture?
    private static var sparkCache: SKTexture?

    private static var scale: CGFloat { UITraitCollection.current.displayScale > 0 ? UITraitCollection.current.displayScale : 3 }

    static func coinTexture(diameter: CGFloat) -> SKTexture {
        let key = Int((diameter * 4).rounded())
        if let t = coinCache[key] { return t }
        let t = texture(VaultCoinFace(diameter: diameter))
        coinCache[key] = t
        return t
    }

    /// Soft gold bloom used behind the newest coin and for selection.
    static func glowTexture() -> SKTexture {
        if let glowCache { return glowCache }
        let view = RadialGradient(colors: [Color(hex: "FFE58A").opacity(0.95), Color(hex: "FFC83D").opacity(0.35), .clear],
                                  center: .center, startRadius: 0, endRadius: 32)
            .frame(width: 64, height: 64)
        let t = texture(view)
        glowCache = t
        return t
    }

    static func sparkTexture() -> SKTexture {
        if let sparkCache { return sparkCache }
        let view = Canvas { ctx, size in
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.fill(Sparkle.path(size: size.width), with: .color(.white))
        }
        .frame(width: 24, height: 24)
        let t = texture(view)
        sparkCache = t
        return t
    }

    private static func texture<V: View>(_ view: V) -> SKTexture {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = false
        guard let image = renderer.uiImage else { return SKTexture() }
        let t = SKTexture(image: image)
        t.filteringMode = .linear
        return t
    }
}
