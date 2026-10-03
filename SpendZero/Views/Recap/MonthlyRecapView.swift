import SwiftUI

/// Story-style Monthly Recap: five full-screen cards with segmented progress bars.
/// Tap right/left to skip/go back, press and hold to pause, swipe down to close.
/// Under Reduce Motion or VoiceOver there is no auto-advance; a Next button appears instead.
struct MonthlyRecapView: View {
    let recap: MonthRecap
    let onClose: () -> Void

    static let cardCount = 5
    /// Seconds each card stays up before auto-advancing (the last card waits for the user).
    static let durations: [Double] = [6.5, 6.2, 5.8, 6.2, 7]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var index = 0
    @State private var replay = 0
    @State private var clock = StoryClock()
    @State private var held = false
    @State private var dragY: CGFloat = 0
    @State private var shareImage: Image?

    private var autoAdvance: Bool { !reduceMotion && !voiceOver }
    private var isLast: Bool { index == Self.cardCount - 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                card
                    .id("\(index)-\(replay)")
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.04)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))))
                    .allowsHitTesting(false)

                // Gesture surface sits between the card and the chrome so buttons stay tappable.
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(coordinateSpace: .local) { point in
                        point.x < geo.size.width * 0.3 ? back() : next()
                    }
                    .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 24, perform: {}) { pressing in
                        setHeld(pressing)
                    }
                    .simultaneousGesture(dismissDrag(height: geo.size.height))
                    .accessibilityHidden(true)

                chrome
                    .opacity(held ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: held)
            }
            .clipShape(RoundedRectangle(cornerRadius: dragY > 0 ? 36 : 0, style: .continuous))
            .scaleEffect(1 - min(dragY, 400) / 2200, anchor: .top)
            .offset(y: dragY)
        }
        .background(Color.black.opacity(Double(1 - min(dragY, 500) / 600)).ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .accessibilityAction(named: Text(String(localized: "Next card"))) { next() }
        .accessibilityAction(named: Text(String(localized: "Previous card"))) { back() }
        .accessibilityAction(.escape) { close() }
        .onAppear { if shareImage == nil { shareImage = RecapStoryCard.render(recap) } }
        .task(id: "\(index)-\(replay)") { await runClock() }
    }

    @ViewBuilder private var card: some View {
        switch index {
        case 0: RecapSealedCard(recap: recap)
        case 1: RecapMoneyCard(recap: recap)
        case 2: RecapStreakCard(recap: recap)
        case 3: RecapUrgesCard(recap: recap)
        default: RecapTreeCard(recap: recap)
        }
    }

    // MARK: Chrome

    private var chrome: some View {
        VStack(spacing: 0) {
            StoryProgressBars(count: Self.cardCount, index: index, clock: clock, live: autoAdvance)
                .padding(.top, 8)
                .accessibilityElement()
                .accessibilityLabel(String(localized: "Card \(index + 1) of \(Self.cardCount)"))

            HStack(spacing: 10) {
                Image("BrandIcon").resizable().frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "SpendZero")
                        .font(.app(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(String(localized: "\(recap.monthName) recap"))
                        .font(.app(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
                .accessibilityElement(children: .combine)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.14)))
                        .contentShape(Rectangle().inset(by: -6))
                }
                .accessibilityLabel(String(localized: "Close recap"))
            }
            .padding(.top, 12)

            Spacer()

            HStack(spacing: 10) {
                if isLast {
                    if let shareImage {
                        ShareLink(item: shareImage,
                                  preview: SharePreview(String(localized: "My \(recap.monthName) on SpendZero"), image: shareImage)) {
                            Label(String(localized: "Share to Stories"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(RecapPrimaryButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded { CoinHaptics.tick() })
                    }
                    Button(String(localized: "Done"), action: close)
                        .buttonStyle(RecapSecondaryButtonStyle())
                } else if !autoAdvance {
                    Spacer()
                    Button(String(localized: "Next"), action: next)
                        .buttonStyle(RecapSecondaryButtonStyle())
                }
            }
            .transition(.opacity)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Navigation

    private func next() {
        guard !isLast else { return }
        CoinHaptics.tick()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.38)) { index += 1 }
    }

    private func back() {
        CoinHaptics.tick()
        if index == 0 {
            replay += 1
        } else {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.38)) { index -= 1 }
        }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) { dragY = 0 }
        onClose()
    }

    private func setHeld(_ pressing: Bool) {
        held = pressing
        pressing ? clock.pause() : clock.resume()
    }

    private func dismissDrag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { v in
                guard v.translation.height > 0, abs(v.translation.height) > abs(v.translation.width) else { return }
                dragY = v.translation.height
                clock.pause()
            }
            .onEnded { v in
                if v.translation.height > 140 || v.predictedEndTranslation.height > height * 0.45 {
                    withAnimation(.easeIn(duration: 0.22)) { dragY = height }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onClose() }
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.25)) { dragY = 0 }
                    clock.resume()
                }
            }
    }

    private func runClock() async {
        clock.restart(duration: Self.durations[min(index, Self.durations.count - 1)])
        guard autoAdvance else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(80))
            if clock.progress(at: Date()) >= 1 {
                if !isLast { next() }
                return
            }
        }
    }
}

// MARK: - Clock

/// Elapsed time for the current card, pausable. Read every frame by the progress bars.
final class StoryClock {
    private(set) var duration: Double = 6
    private var started = Date()
    private var pausedAt: Date?
    private var pausedTotal: Double = 0

    func restart(duration: Double) {
        self.duration = max(0.1, duration)
        started = Date()
        pausedAt = nil
        pausedTotal = 0
    }

    func pause() { if pausedAt == nil { pausedAt = Date() } }

    func resume() {
        guard let p = pausedAt else { return }
        pausedTotal += Date().timeIntervalSince(p)
        pausedAt = nil
    }

    func progress(at date: Date) -> Double {
        let now = pausedAt ?? date
        return min(1, max(0, (now.timeIntervalSince(started) - pausedTotal) / duration))
    }
}

/// Instagram-style segmented bars; the current one fills with the clock.
struct StoryProgressBars: View {
    let count: Int
    let index: Int
    let clock: StoryClock
    let live: Bool

    var body: some View {
        TimelineView(.animation(paused: !live)) { tl in
            let current = live ? clock.progress(at: tl.date) : 1
            HStack(spacing: 5) {
                ForEach(0..<count, id: \.self) { i in
                    GeometryReader { g in
                        Capsule().fill(.white.opacity(0.28))
                            .overlay(alignment: .leading) {
                                Capsule().fill(.white)
                                    .frame(width: g.size.width * (i < index ? 1 : i == index ? current : 0))
                            }
                    }
                    .frame(height: 3)
                }
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2)
    }
}

#Preview {
    MonthlyRecapView(recap: .demo(), onClose: {})
}
