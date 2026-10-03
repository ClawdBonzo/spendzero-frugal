import SpriteKit
import SwiftUI

/// One sealed no-spend day, as it lives in the jar.
struct VaultCoin: Equatable, Identifiable {
    let id: UUID
    let date: Date
    /// 1-based position among every coin ever minted.
    let day: Int
    let amount: Double
}

/// The jar's physics: coins are metal discs that settle, slide with device tilt and clink.
/// Coordinates handed to and from SwiftUI are view points with y pointing down.
final class VaultScene: SKScene, SKPhysicsContactDelegate {
    private enum Category {
        static let glass: UInt32 = 1 << 0
        static let coin: UInt32 = 1 << 1
    }

    /// Called once a dropped coin has landed (or appeared, without physics).
    var onLanded: ((VaultCoin) -> Void)?

    /// Static pile with no physics and no tilt (Reduce Motion).
    var isStatic = false {
        didSet { if oldValue != isStatic { rebuild() } }
    }

    private(set) var geometry: JarGeometry?
    private var coins: [VaultCoin] = []
    private var nodes: [SKSpriteNode] = []
    private var dropping: (coin: VaultCoin, node: SKSpriteNode, started: TimeInterval)?
    private var selectedID: UUID?

    private let newestGlow = SKSpriteNode(texture: nil)
    private let selectionGlow = SKSpriteNode(texture: nil)
    private let landingSparks = SKEmitterNode()
    private let mintSparks = SKEmitterNode()

    private var lastTime: TimeInterval = 0
    private var lastTiltX: CGFloat = 0
    private var lastShake: TimeInterval = 0
    private var lastClink: TimeInterval = 0
    private var now: TimeInterval = 0

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = .zero
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Content

    /// Shows `coins` as a settled pile. When `dropNewest` is set, the last coin is minted above the
    /// lid and dropped through the slot instead of being placed.
    func show(_ coins: [VaultCoin], dropNewest: Bool) {
        let base = dropNewest ? Array(coins.dropLast()) : coins
        if base.map(\.id) != self.coins.map(\.id) || nodes.count != base.count {
            self.coins = base
            rebuild()
        }
        if dropNewest, let newest = coins.last, !self.coins.contains(where: { $0.id == newest.id }) {
            drop(newest)
        }
    }

    /// Shrinks every coin into the centre of the jar (the jar sealing into a bar), then empties it.
    func meltAll(completion: @escaping () -> Void) {
        guard let geometry, !nodes.isEmpty else { completion(); return }
        let centre = point(CGPoint(x: geometry.jarRect.midX, y: geometry.jarRect.midY + geometry.jarRect.height * 0.12))
        for (i, node) in nodes.enumerated() {
            node.physicsBody = nil
            let delay = SKAction.wait(forDuration: Double(i % 25) * 0.008)
            let gather = SKAction.group([
                SKAction.move(to: centre, duration: 0.45),
                SKAction.scale(to: 0.2, duration: 0.45),
                SKAction.fadeOut(withDuration: 0.45)
            ])
            gather.timingMode = .easeIn
            node.run(SKAction.sequence([delay, gather]))
        }
        run(SKAction.sequence([SKAction.wait(forDuration: 0.7), SKAction.run { [weak self] in
            self?.coins = []
            self?.rebuild()
            completion()
        }]))
    }

    /// The coin under a SwiftUI point, and its centre in SwiftUI space.
    func coin(atViewPoint p: CGPoint) -> (VaultCoin, CGPoint)? {
        guard let geometry else { return nil }
        let target = point(p)
        let reach = geometry.coinRadius * 1.35
        var best: (Int, CGFloat)?
        for (i, node) in nodes.enumerated() {
            let d = hypot(node.position.x - target.x, node.position.y - target.y)
            if d < reach, d < (best?.1 ?? .greatestFiniteMagnitude) { best = (i, d) }
        }
        guard let (i, _) = best else { return nil }
        return (coins[i], viewPoint(nodes[i].position))
    }

    /// Where a coin currently is, in SwiftUI space.
    func viewPosition(of id: UUID) -> CGPoint? {
        guard let i = coins.firstIndex(where: { $0.id == id }), i < nodes.count else { return nil }
        return viewPoint(nodes[i].position)
    }

    func select(_ id: UUID?) {
        selectedID = id
        selectionGlow.removeFromParent()
        guard let id, let i = coins.firstIndex(where: { $0.id == id }), i < nodes.count else { return }
        selectionGlow.removeAllActions()
        selectionGlow.setScale(0.6)
        selectionGlow.alpha = 0
        nodes[i].addChild(selectionGlow)
        let pulse = SKAction.sequence([SKAction.fadeAlpha(to: 1, duration: 0.5), SKAction.fadeAlpha(to: 0.65, duration: 0.5)])
        selectionGlow.run(SKAction.group([
            SKAction.scale(to: 1, duration: 0.25),
            SKAction.repeatForever(pulse)
        ]))
    }

    // MARK: - Building

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 40, size.height > 40, geometry?.size != size else { return }
        rebuild()
    }

    private func rebuild() {
        guard size.width > 40, size.height > 40 else { return }
        removeAllActions()
        for node in nodes { node.removeFromParent() }
        nodes.removeAll(keepingCapacity: true)
        if let d = dropping { d.node.removeFromParent(); dropping = nil }

        let g = JarGeometry(size: size)
        geometry = g

        // The glass: a closed loop (lid included) so tilting can never spill a coin.
        let boundary = CGMutablePath()
        boundary.addLines(between: g.inner.map(point))
        boundary.closeSubpath()
        let glass = SKPhysicsBody(edgeLoopFrom: boundary)
        glass.categoryBitMask = Category.glass
        glass.friction = 0.25
        glass.restitution = 0.15
        physicsBody = glass

        configureEffects(g)

        let texture = VaultArt.coinTexture(diameter: g.coinRadius * 2)
        let spots = g.settledPile(count: coins.count)
        for (coin, spot) in zip(coins, spots) {
            let node = makeCoinNode(coin, texture: texture, radius: g.coinRadius)
            node.position = point(spot)
            if !isStatic { node.physicsBody = makeBody(radius: g.coinRadius) }
            addChild(node)
            nodes.append(node)
        }
        attachNewestGlow()
        if let selectedID { select(selectedID) }
    }

    private func makeCoinNode(_ coin: VaultCoin, texture: SKTexture, radius: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: radius * 2 * VaultArt.padding, height: radius * 2 * VaultArt.padding)
        node.zPosition = 1
        // A touch of tone variation so the pile reads as many coins, not one stamp.
        let h = coin.id.uuid
        node.color = .black
        node.colorBlendFactor = CGFloat(h.0 % 10) / 100
        return node
    }

    private func makeBody(radius: CGFloat) -> SKPhysicsBody {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.categoryBitMask = Category.coin
        body.collisionBitMask = Category.coin | Category.glass
        body.contactTestBitMask = Category.coin | Category.glass
        body.allowsRotation = false
        body.friction = 0.42
        body.restitution = 0.28
        body.linearDamping = 0.35
        body.density = 2.4
        return body
    }

    private func configureEffects(_ g: JarGeometry) {
        newestGlow.texture = VaultArt.glowTexture()
        newestGlow.size = CGSize(width: g.coinRadius * 4.2, height: g.coinRadius * 4.2)
        newestGlow.blendMode = .add
        newestGlow.zPosition = -0.6
        newestGlow.alpha = 0.55

        selectionGlow.texture = VaultArt.glowTexture()
        selectionGlow.size = CGSize(width: g.coinRadius * 5, height: g.coinRadius * 5)
        selectionGlow.blendMode = .add
        selectionGlow.zPosition = 0.5

        for emitter in [landingSparks, mintSparks] {
            emitter.removeFromParent()
            emitter.particleTexture = VaultArt.sparkTexture()
            emitter.particleBirthRate = 0
            emitter.particleLifetime = 0.55
            emitter.particleLifetimeRange = 0.25
            emitter.particleSpeed = 90
            emitter.particleSpeedRange = 60
            emitter.emissionAngleRange = .pi * 2
            emitter.particleAlphaSpeed = -1.8
            emitter.particleScale = 0.32
            emitter.particleScaleRange = 0.2
            emitter.particleScaleSpeed = -0.4
            emitter.particleColor = UIColor(red: 1, green: 0.86, blue: 0.4, alpha: 1)
            emitter.particleColorBlendFactor = 1
            emitter.particleBlendMode = .add
            emitter.zPosition = 5
            addChild(emitter)
        }
        landingSparks.emissionAngle = .pi / 2
        landingSparks.emissionAngleRange = .pi * 0.9
        landingSparks.yAcceleration = -260
    }

    private func attachNewestGlow() {
        newestGlow.removeFromParent()
        newestGlow.removeAllActions()
        guard let last = nodes.last else { return }
        last.addChild(newestGlow)
        guard !isStatic else { return }
        let breathe = SKAction.sequence([SKAction.fadeAlpha(to: 0.85, duration: 1.4), SKAction.fadeAlpha(to: 0.45, duration: 1.4)])
        breathe.timingMode = .easeInEaseOut
        newestGlow.run(SKAction.repeatForever(breathe))
    }

    private func burst(_ emitter: SKEmitterNode, at p: CGPoint, count: Int) {
        emitter.position = p
        emitter.resetSimulation()
        emitter.numParticlesToEmit = count
        emitter.particleBirthRate = CGFloat(count) * 30
    }

    // MARK: - Dropping a coin

    private func drop(_ coin: VaultCoin) {
        guard let g = geometry else { return }
        let texture = VaultArt.coinTexture(diameter: g.coinRadius * 2)
        let node = makeCoinNode(coin, texture: texture, radius: g.coinRadius)

        guard !isStatic else {
            // Reduce Motion: the coin simply appears in its place in the pile.
            let spot = g.settledPile(count: coins.count + 1).last ?? CGPoint(x: g.jarRect.midX, y: g.innerBottom)
            node.position = point(spot)
            node.alpha = 0
            addChild(node)
            coins.append(coin)
            nodes.append(node)
            attachNewestGlow()
            node.run(SKAction.fadeIn(withDuration: 0.25))
            onLanded?(coin)
            return
        }

        // 1. Mint: the coin appears above the lid with a sparkle and two quick flips.
        node.position = point(g.mintPoint)
        node.alpha = 0
        node.setScale(0.5)
        node.zPosition = 3
        addChild(node)
        burst(mintSparks, at: node.position, count: 18)
        let flip = SKAction.sequence([SKAction.scaleX(to: 0.08, duration: 0.11), SKAction.scaleX(to: 1, duration: 0.11)])
        flip.timingMode = .easeInEaseOut
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1.12, duration: 0.25),
            SKAction.moveBy(x: 0, y: 8, duration: 0.3)
        ])
        appear.timingMode = .easeOut
        // 2. Fall through the slot (the lid is drawn over the scene, so it passes behind it).
        let entry = point(g.entryPoint)
        let fall = SKAction.group([
            SKAction.move(to: entry, duration: 0.26),
            SKAction.scale(to: 1, duration: 0.26)
        ])
        fall.timingMode = .easeIn
        // 3. Physics takes over inside the jar.
        let release = SKAction.run { [weak self, weak node] in
            guard let self, let node else { return }
            let body = self.makeBody(radius: g.coinRadius)
            body.usesPreciseCollisionDetection = true
            body.velocity = CGVector(dx: CGFloat.random(in: -40...40), dy: -420)
            node.physicsBody = body
            node.zPosition = 1
            self.coins.append(coin)
            self.nodes.append(node)
            self.dropping = (coin, node, self.now)
        }
        node.run(SKAction.sequence([
            appear,
            SKAction.repeat(flip, count: 2),
            SKAction.wait(forDuration: 0.12),
            fall,
            release
        ]))
    }

    private func land() {
        guard let d = dropping else { return }
        dropping = nil
        d.node.physicsBody?.usesPreciseCollisionDetection = false
        burst(landingSparks, at: CGPoint(x: d.node.position.x, y: d.node.position.y - (geometry?.coinRadius ?? 0) * 0.6), count: 14)
        attachNewestGlow()
        MainActor.assumeIsolated {
            CoinHaptics.seal()
            SoundEffects.play(.clink, volume: 0.4)
        }
        lastClink = now
        onLanded?(d.coin)
    }

    // MARK: - Simulation

    override func update(_ currentTime: TimeInterval) {
        now = currentTime
        let dt = lastTime > 0 ? min(0.1, currentTime - lastTime) : 0
        lastTime = currentTime
        guard !isStatic else { return }

        let tilt = MainActor.assumeIsolated { TiltMotion.shared.tilt }
        let tx = max(-1, min(1, tilt.x)) * 0.85
        physicsWorld.gravity = CGVector(dx: tx * 9.8, dy: -sqrt(1 - tx * tx) * 9.8)

        // A quick flick of the wrist jostles the pile: the coins lag behind the jar.
        if dt > 0 {
            let speed = (tilt.x - lastTiltX) / dt
            if abs(speed) > 2.2, currentTime - lastShake > 0.14 {
                lastShake = currentTime
                let push = max(-3.5, min(3.5, -speed)) * 0.010
                for node in nodes {
                    guard let body = node.physicsBody else { continue }
                    body.applyImpulse(CGVector(dx: push * body.mass * 40, dy: CGFloat.random(in: 0.2...1) * abs(push) * body.mass * 55))
                }
            }
        }
        lastTiltX = tilt.x

        // Safety net: if the dropped coin never reports a contact, land it anyway.
        if let d = dropping, currentTime - d.started > 1.6 { land() }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        if let d = dropping, contact.bodyA.node === d.node || contact.bodyB.node === d.node {
            land()
            return
        }
        // Coins knocking together when the jar is tilted or shaken.
        let impulse = contact.collisionImpulse
        guard impulse > 0.03, now - lastClink > 0.09 else { return }
        lastClink = now
        let volume = Float(min(0.3, 0.06 + impulse * 1.6))
        MainActor.assumeIsolated { SoundEffects.play(.clink, volume: volume) }
    }

    // MARK: - Coordinates

    private func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: size.height - p.y) }
    private func viewPoint(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: size.height - p.y) }
}
