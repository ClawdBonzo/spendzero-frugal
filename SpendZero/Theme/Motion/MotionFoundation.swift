import SwiftUI
import CoreMotion
import CoreHaptics
import AVFoundation

// MARK: - Device tilt

/// Smoothed device tilt in -1…1 on both axes, shared by every gold and foil surface.
/// Runs only while at least one surface is on screen, and never under Reduce Motion.
@MainActor
@Observable
final class TiltMotion {
    static let shared = TiltMotion()

    private(set) var tilt: CGPoint = .zero

    private let manager = CMMotionManager()
    private var users = 0

    private init() {}

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable, !UIAccessibility.isReduceMotionEnabled else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                // Phones are usually held tilted back ~35°; treat that as neutral.
                let x = max(-1, min(1, motion.attitude.roll / 0.6))
                let y = max(-1, min(1, (motion.attitude.pitch - 0.6) / 0.6))
                self.tilt = CGPoint(x: self.tilt.x * 0.82 + x * 0.18, y: self.tilt.y * 0.82 + y * 0.18)
            }
        }
    }

    func stop() {
        users = max(0, users - 1)
        if users == 0 { manager.stopDeviceMotionUpdates() }
    }
}

// MARK: - Gold and foil materials

private struct ShaderMaterial: ViewModifier {
    enum Kind { case gold, foil }
    let kind: Kind
    let strength: Double

    @State private var motion = TiltMotion.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
            let time = Float(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
            let tilt = motion.tilt
            let strength = Float(strength)
            let kind = kind
            content.visualEffect { view, proxy in
                let size = CGPoint(x: proxy.size.width, y: proxy.size.height)
                let shader = kind == .gold
                    ? ShaderLibrary.goldSheen(.float2(size), .float2(tilt), .float(time), .float(strength))
                    : ShaderLibrary.holoFoil(.float2(size), .float2(tilt), .float(time), .float(strength))
                return view.colorEffect(shader)
            }
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }
}

extension View {
    /// Metallic highlight that follows the phone's tilt. Apply to anything drawn in gold.
    func goldSheen(_ strength: Double = 1) -> some View { modifier(ShaderMaterial(kind: .gold, strength: strength)) }
    /// Holographic rainbow foil that shifts with the viewing angle (badges, rare rewards).
    func holoFoil(_ strength: Double = 1) -> some View { modifier(ShaderMaterial(kind: .foil, strength: strength)) }
}

// MARK: - Numbers that move like objects

/// Money that rolls digit by digit when it changes, with a light tick.
struct RollingMoney: View {
    let value: Double
    var font: Font = .app(size: 28, weight: .black, design: .rounded)
    var color: Color = AppTheme.primaryGreen

    var body: some View {
        Text(value.currencyFormatted)
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
            .animation(.snappy(duration: 0.6), value: value)
            .sensoryFeedback(.increase, trigger: value)
    }
}

/// An integer that flips like a departure board when it changes.
struct FlipCounter: View {
    let value: Int
    var font: Font = .app(size: 44, weight: .black, design: .rounded)
    var color: Color = AppTheme.textPrimary

    @State private var shown: Int = 0
    @State private var flip = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(shown)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .rotation3DEffect(.degrees(flip), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .onAppear { shown = value }
            .onChange(of: value) { _, new in
                guard !reduceMotion else { shown = new; return }
                withAnimation(.easeIn(duration: 0.14)) { flip = 90 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    shown = new
                    flip = -90
                    withAnimation(.spring(duration: 0.32, bounce: 0.35)) { flip = 0 }
                }
            }
            .accessibilityLabel(Text("\(value)"))
    }
}

// MARK: - Living background

/// A slow-moving mesh of deep greens that warms toward gold as `warmth` rises (0…1).
struct LivingBackground: View {
    var warmth: Double = 0.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3,
                         points: Self.points(t),
                         colors: Self.colors(max(0, min(1, warmth))))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func points(_ t: Double) -> [SIMD2<Float>] {
        func d(_ speed: Double, _ phase: Double) -> Float { Float(0.08 * sin(t * speed + phase)) }
        let top: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(0.5 + d(0.21, 0), 0), SIMD2(1, 0)]
        let mid: [SIMD2<Float>] = [SIMD2(0, 0.5 + d(0.17, 1)), SIMD2(0.5 + d(0.13, 2), 0.5 + d(0.19, 3)), SIMD2(1, 0.5 + d(0.23, 4))]
        let bottom: [SIMD2<Float>] = [SIMD2(0, 1), SIMD2(0.5 + d(0.15, 5), 1), SIMD2(1, 1)]
        return top + mid + bottom
    }

    private static func colors(_ w: Double) -> [Color] {
        let night = Color(hex: "0A0E14"), deep = Color(hex: "0B2A20"), green = Color(hex: "0C3326")
        let centre = mix(Color(hex: "0E4A33"), Color(hex: "4A3A0C"), w)
        let lower = mix(Color(hex: "0B2A20"), Color(hex: "2E2408"), w)
        return [night, deep, night, green, centre, deep, night, lower, Color(hex: "070A0F")]
    }

    private static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ra = UIColor(a).cgColor.components ?? [0, 0, 0, 1]
        let rb = UIColor(b).cgColor.components ?? [0, 0, 0, 1]
        func c(_ i: Int) -> Double { Double(ra[min(i, ra.count - 1)]) * (1 - t) + Double(rb[min(i, rb.count - 1)]) * t }
        return Color(red: c(0), green: c(1), blue: c(2))
    }
}

// MARK: - Haptic signatures

/// Custom Core Haptics patterns for SpendZero's key moments; falls back to UIKit feedback.
@MainActor
enum CoinHaptics {
    private static let engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, let e = try? CHHapticEngine() else { return nil }
        e.isAutoShutdownEnabled = true
        e.resetHandler = { try? e.start() }
        return e
    }()

    /// A coin landing: a sharp thud, then a short metallic ring.
    static func seal() {
        play([
            transient(at: 0, intensity: 1, sharpness: 0.75),
            continuous(at: 0.02, duration: 0.32, intensity: 0.45, sharpness: 0.95, decay: true),
            transient(at: 0.13, intensity: 0.55, sharpness: 0.9)
        ], fallback: { Beat.stamp() })
    }

    /// Three rising steps.
    static func levelUp() {
        play([
            transient(at: 0, intensity: 0.5, sharpness: 0.4),
            transient(at: 0.11, intensity: 0.75, sharpness: 0.6),
            transient(at: 0.22, intensity: 1, sharpness: 0.85),
            continuous(at: 0.24, duration: 0.3, intensity: 0.4, sharpness: 0.7, decay: true)
        ], fallback: { UINotificationFeedbackGenerator().notificationOccurred(.success) })
    }

    /// A soft fade for a broken streak: noticeable, never punishing.
    static func streakLost() {
        play([continuous(at: 0, duration: 0.5, intensity: 0.5, sharpness: 0.15, decay: true)],
             fallback: { UIImpactFeedbackGenerator(style: .soft).impactOccurred() })
    }

    /// The lightest tick, for counters and coin taps.
    static func tick() {
        play([transient(at: 0, intensity: 0.35, sharpness: 0.8)],
             fallback: { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5) })
    }

    private static func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time)
    }

    private static func continuous(at time: TimeInterval, duration: TimeInterval, intensity: Float,
                                   sharpness: Float, decay: Bool) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            CHHapticEventParameter(parameterID: .decayTime, value: decay ? Float(duration) : 0),
            CHHapticEventParameter(parameterID: .sustained, value: decay ? 0 : 1)
        ], relativeTime: time, duration: duration)
    }

    private static func play(_ events: [CHHapticEvent], fallback: () -> Void) {
        guard let engine, let pattern = try? CHHapticPattern(events: events, parameters: []) else { fallback(); return }
        do {
            try engine.start()
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }
}

// MARK: - Sound

/// Tiny UI sounds. Uses the ambient session, so the ring/silent switch mutes them and music keeps playing.
@MainActor
enum SoundEffects {
    enum Effect: String, CaseIterable { case clink, chime, levelUp = "levelup", flip }

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundEffectsEnabled") }
    }

    private static var players: [Effect: AVAudioPlayer] = [:]
    private static var configured = false

    static func play(_ effect: Effect, volume: Float = 0.6) {
        guard isEnabled else { return }
        if !configured {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            configured = true
        }
        if players[effect] == nil, let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
            players[effect] = try? AVAudioPlayer(contentsOf: url)
            players[effect]?.prepareToPlay()
        }
        guard let player = players[effect] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}
