import SwiftUI

/// The shape of the Coin Vault jar, shared by the SwiftUI glass and the SpriteKit physics so the
/// coins collide with exactly the glass you see. All values are in view points, y pointing down.
struct JarGeometry: Equatable {
    static let capacity = 100

    let size: CGSize
    /// Outer glass silhouette (neck top to neck top, closed under the lid).
    let outer: [CGPoint]
    /// Inner wall of the glass: the physics boundary.
    let inner: [CGPoint]
    let jarRect: CGRect
    let lidRect: CGRect
    let neckWidth: CGFloat
    /// Where the coin appears before it is dropped through the slot.
    let mintPoint: CGPoint
    /// Just inside the neck, under the lid: where a dropped coin starts to fall freely.
    let entryPoint: CGPoint
    let coinRadius: CGFloat

    // Interior measurements used to lay out a settled pile.
    let innerLeft: CGFloat
    let innerRight: CGFloat
    let innerBottom: CGFloat
    let innerCorner: CGFloat
    let shoulderBottom: CGFloat

    init(size: CGSize) {
        self.size = size
        let width = min(size.width * 0.66, 250)
        let lidHeight: CGFloat = 20
        let lidTop: CGFloat = 54
        let neck = width * 0.5
        let jarTop = lidTop + lidHeight - 3
        let jar = CGRect(x: (size.width - width) / 2, y: jarTop, width: width,
                         height: max(120, size.height - jarTop - 46))
        let neckHeight: CGFloat = 14
        let shoulder = width * 0.17
        let corner = width * 0.2
        let wall: CGFloat = 4

        jarRect = jar
        neckWidth = neck
        lidRect = CGRect(x: size.width / 2 - (neck + 18) / 2, y: lidTop, width: neck + 18, height: lidHeight)
        outer = Self.outline(jar, neck: neck, neckHeight: neckHeight, shoulder: shoulder, corner: corner)
        let innerFrame = CGRect(x: jar.minX + wall, y: jar.minY, width: jar.width - wall * 2, height: jar.height - wall)
        inner = Self.outline(innerFrame, neck: neck - wall * 2, neckHeight: neckHeight, shoulder: shoulder, corner: corner - wall)

        innerLeft = innerFrame.minX
        innerRight = innerFrame.maxX
        innerBottom = innerFrame.maxY
        innerCorner = corner - wall
        shoulderBottom = jar.minY + neckHeight + shoulder

        // Size coins so a full jar (100) fills roughly four fifths of the straight body.
        let bodyArea = innerFrame.width * (innerBottom - shoulderBottom) - (4 - .pi) * innerCorner * innerCorner
        let r = sqrt(bodyArea * 0.80 * 0.80 / (CGFloat(Self.capacity) * .pi))
        coinRadius = min(16, max(7, r))

        mintPoint = CGPoint(x: size.width / 2, y: lidTop - coinRadius - 16)
        entryPoint = CGPoint(x: size.width / 2, y: jar.minY + neckHeight + coinRadius * 0.4)
    }

    /// A smooth jar silhouette sampled to a polygon: neck, rounded shoulders, straight walls, rounded base.
    private static func outline(_ r: CGRect, neck: CGFloat, neckHeight: CGFloat, shoulder: CGFloat, corner: CGFloat) -> [CGPoint] {
        var pts: [CGPoint] = []
        let cx = r.midX
        let nl = cx - neck / 2, nr = cx + neck / 2
        let neckBottom = r.minY + neckHeight
        let wallTop = neckBottom + shoulder

        func cubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p3: CGPoint, steps: Int = 18) {
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps), u = 1 - t
                let x = u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p3.x
                let y = u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p3.y
                pts.append(CGPoint(x: x, y: y))
            }
        }
        func arc(center: CGPoint, radius: CGFloat, from a0: CGFloat, to a1: CGFloat, steps: Int = 14) {
            for i in 1...steps {
                let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
                pts.append(CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius))
            }
        }

        pts.append(CGPoint(x: nl, y: r.minY))
        pts.append(CGPoint(x: nl, y: neckBottom))
        cubic(CGPoint(x: nl, y: neckBottom), CGPoint(x: nl - neck * 0.08, y: neckBottom + shoulder * 0.62),
              CGPoint(x: r.minX, y: neckBottom + shoulder * 0.18), CGPoint(x: r.minX, y: wallTop))
        pts.append(CGPoint(x: r.minX, y: r.maxY - corner))
        arc(center: CGPoint(x: r.minX + corner, y: r.maxY - corner), radius: corner, from: .pi, to: .pi / 2)
        pts.append(CGPoint(x: r.maxX - corner, y: r.maxY))
        arc(center: CGPoint(x: r.maxX - corner, y: r.maxY - corner), radius: corner, from: .pi / 2, to: 0)
        pts.append(CGPoint(x: r.maxX, y: wallTop))
        cubic(CGPoint(x: r.maxX, y: wallTop), CGPoint(x: r.maxX, y: neckBottom + shoulder * 0.18),
              CGPoint(x: nr + neck * 0.08, y: neckBottom + shoulder * 0.62), CGPoint(x: nr, y: neckBottom))
        pts.append(CGPoint(x: nr, y: r.minY))
        return pts
    }

    var outerPath: Path { Self.path(outer) }
    var innerPath: Path { Self.path(inner) }

    static func path(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    // MARK: - Settled pile

    /// Lowest resting height (y, pointing down) for a coin centred at `x` on the jar's floor.
    private func floorY(at x: CGFloat) -> CGFloat {
        let r = coinRadius
        let reach = innerCorner - r
        let leftC = innerLeft + innerCorner, rightC = innerRight - innerCorner
        let cy = innerBottom - innerCorner
        if x < leftC {
            let dx = x - leftC
            return cy + sqrt(max(0, reach * reach - dx * dx))
        }
        if x > rightC {
            let dx = x - rightC
            return cy + sqrt(max(0, reach * reach - dx * dx))
        }
        return innerBottom - r
    }

    /// A deterministic, physically plausible pile: each coin falls in near the centre and settles
    /// in the lowest of a few nearby spots. The pile for `n` coins is a prefix of the pile for
    /// `n + 1`, so a returning user always sees the same jar.
    func settledPile(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let r = coinRadius
        let minX = innerLeft + r + 0.5, maxX = innerRight - r - 0.5
        let mid = (minX + maxX) / 2, half = (maxX - minX) / 2
        var rng = SeededGenerator(seed: 0x5EA1_C011)
        var placed: [CGPoint] = []
        placed.reserveCapacity(count)
        for _ in 0..<count {
            var best = CGPoint(x: mid, y: -.greatestFiniteMagnitude)
            for _ in 0..<6 {
                // Triangular spread around the neck: coins fall in the middle and slide outwards.
                let u = Double.random(in: -1...1, using: &rng) + Double.random(in: -1...1, using: &rng)
                let x = min(maxX, max(minX, mid + CGFloat(u / 2) * half * 1.15))
                var y = floorY(at: x)
                for p in placed where abs(p.x - x) < 2 * r {
                    let dx = p.x - x
                    y = min(y, p.y - sqrt(4 * r * r - dx * dx) - 0.3)
                }
                if y > best.y { best = CGPoint(x: x, y: y) }
            }
            placed.append(best)
        }
        return placed
    }
}
