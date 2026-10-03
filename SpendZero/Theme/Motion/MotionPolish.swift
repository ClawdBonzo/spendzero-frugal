import SwiftUI

// MARK: - Pressable buttons

/// Buttons compress slightly on touch-down and spring back, with a light tick.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, scale: scale)
    }

    private struct PressableBody: View {
        let configuration: Configuration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
                .brightness(configuration.isPressed ? -0.04 : 0)
                .animation(.spring(duration: 0.28, bounce: 0.45), value: configuration.isPressed)
                .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: configuration.isPressed) { _, pressed in pressed }
        }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Self-drawing checkmark

/// A checkmark stroke that draws itself in when `isOn` becomes true.
struct DrawnCheckmark: View {
    var isOn: Bool
    var color: Color = AppTheme.primaryGreen
    var lineWidth: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CheckmarkShape()
            .trim(from: 0, to: isOn ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: isOn)
            .accessibilityHidden(true)
    }

    private struct CheckmarkShape: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY + rect.height * 0.04))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - rect.height * 0.16))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.2))
            return p
        }
    }
}

// MARK: - Liquid Glass (iOS 26) with a fallback

extension View {
    /// Apple's Liquid Glass on iOS 26 and later; the app's solid card everywhere else.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = AppTheme.cornerRadiusLarge, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            let glass: Glass = tint.map { Glass.regular.tint($0.opacity(0.18)) } ?? .regular
            self.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(RoundedRectangle(cornerRadius: cornerRadius).fill(AppTheme.cardBackground))
        }
    }

    /// Glass-style secondary button on iOS 26; the pressable style elsewhere.
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.pressable)
        }
    }

    /// Cards that settle in as they scroll into view and recede at the edges.
    func scrollDepth() -> some View {
        scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                .opacity(phase.isIdentity ? 1 : 0.55)
                .blur(radius: phase.isIdentity ? 0 : 1.5)
        }
    }
}
