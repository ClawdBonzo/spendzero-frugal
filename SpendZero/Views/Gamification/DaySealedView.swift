import SwiftUI

/// The moment a no-spend day is logged: a minted coin stamps down, the streak counts up, the
/// day's rewards pop in, and the next milestone is shown — then it can be shared as a story.
/// Beats: stamp (0s) → thump + shockwave + confetti (0.3s) → streak count (0.55s) → rewards (0.9s)
/// → actions (1.4s).
struct DaySealedView: View {
    let info: EventPresenter.DaySealed
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamped = false
    @State private var shockwave = false
    @State private var streakShown: Double
    @State private var showDetails = false
    @State private var showActions = false
    @State private var confetti = 0
    @State private var shareImage: Image?

    init(info: EventPresenter.DaySealed, onDismiss: @escaping () -> Void) {
        self.info = info
        self.onDismiss = onDismiss
        _streakShown = State(initialValue: Double(info.previousStreak))
    }

    private var today: String { Date().formatted(.dateTime.month(.abbreviated).day()) }

    var body: some View {
        GeometryReader { geo in
            let medal = min(230, geo.size.width * 0.56)
            ZStack {
                AppTheme.background.ignoresSafeArea()
                GlowBackdrop(intensity: 0.2).ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer(minLength: 12)

                    ZStack {
                        ForEach(0..<2, id: \.self) { i in
                            Circle()
                                .stroke(AppTheme.accentGold.opacity(shockwave ? 0 : 0.7), lineWidth: 3)
                                .frame(width: medal, height: medal)
                                .scaleEffect(shockwave ? 1.7 + 0.35 * Double(i) : 0.95)
                        }
                        SealMedallion(caption: today)
                            .goldSheen()
                            .frame(width: medal, height: medal)
                            .scaleEffect(stamped ? 1 : 2.1)
                            .rotationEffect(.degrees(stamped ? 0 : -14))
                            .opacity(stamped ? 1 : 0)
                            .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
                    }
                    .frame(width: medal, height: medal * 1.2)
                    // In a background so the rays can spill past the screen edge without widening the layout.
                    .background {
                        Sunburst(rays: 20)
                            .frame(width: medal * 3, height: medal * 3)
                            .opacity(stamped ? 1 : 0)
                    }

                    VStack(spacing: 6) {
                        Text("Day sealed.")
                            .font(.app(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.white, AppTheme.accentGold],
                                                            startPoint: .top, endPoint: .bottom))
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(LinearGradient(colors: [AppTheme.accentGold, Color(hex: "FF6B35")],
                                                                startPoint: .top, endPoint: .bottom))
                                .symbolEffect(.bounce, value: showDetails)
                            CountUpText(value: streakShown) { String(localized: "\($0)-day streak") }
                                .font(.app(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                    .opacity(stamped ? 1 : 0)

                    FlowLayout(spacing: 8) { chips }
                        .padding(.horizontal, 24)
                        .opacity(showDetails ? 1 : 0)
                        .scaleEffect(showDetails ? 1 : 0.9)

                    milestoneCard
                        .padding(.horizontal, 24)
                        .opacity(showDetails ? 1 : 0)
                        .offset(y: showDetails ? 0 : 12)

                    Spacer(minLength: 8)

                    actions
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                        .opacity(showActions ? 1 : 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)

                CashConfettiBurst(trigger: confetti, origin: UnitPoint(x: 0.5, y: 0.26))
                    .ignoresSafeArea()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .contentShape(Rectangle())
        .onTapGesture { if showActions { onDismiss() } }
        .onAppear(perform: play)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "No-spend day sealed. \(info.streak)-day streak."))
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Reward chips

    @ViewBuilder private var chips: some View {
        if info.xp > 0 {
            RewardChip(icon: "star.fill", text: String(localized: "+\(info.xp) XP"), tint: AppTheme.accentGold)
        }
        if info.lucky {
            RewardChip(icon: "sparkles", text: String(localized: "Lucky ×2"), tint: Color(hex: "FF6BD5"))
        }
        if info.saved > 0 {
            RewardChip(icon: "banknote.fill", text: String(localized: "+\(info.saved.currencyFormatted) saved"),
                       tint: AppTheme.primaryGreen)
        }
        if info.freezeEarned {
            RewardChip(icon: "snowflake", text: String(localized: "Streak freeze earned"), tint: Color(hex: "60CFFF"))
        }
        ForEach(info.questsCompleted, id: \.self) { title in
            RewardChip(icon: "checkmark.seal.fill", text: String(localized: "Quest done: \(title)"), tint: AppTheme.primaryGreen)
        }
        if let challenge = info.challengeCompleted {
            RewardChip(icon: "trophy.fill", text: String(localized: "\(challenge) complete"), tint: AppTheme.accentGold)
        }
    }

    // MARK: Next milestone

    @ViewBuilder private var milestoneCard: some View {
        let hitNow = StreakMilestone.days.contains(info.streak)
        let next = StreakMilestone.next(after: info.streak)
        let floor = StreakMilestone.previous(atOrBelow: info.streak)

        VStack(alignment: .leading, spacing: 10) {
            if hitNow {
                Label(String(localized: "\(info.streak)-day milestone reached!"), systemImage: "rosette")
                    .font(.app(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accentGold)
            }
            if let next {
                let left = next - info.streak
                HStack(alignment: .firstTextBaseline) {
                    Text(left == 1 ? String(localized: "1 day to a \(next)-day streak")
                                   : String(localized: "\(left) days to a \(next)-day streak"))
                        .font(.app(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    let rewards = StreakMilestone.rewards(for: next)
                    if !rewards.isEmpty {
                        Text(rewards.joined(separator: " + "))
                            .font(.app(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.accentGold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                MilestoneTrack(from: floor, to: next, current: info.streak)
                    .frame(height: 10)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.cardBackground.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.accentGold.opacity(0.25), lineWidth: 1))
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 12) {
            if let shareImage {
                ShareLink(item: shareImage,
                          preview: SharePreview(String(localized: "My no-spend streak"), image: shareImage)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.app(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.accentGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.accentGold.opacity(0.6), lineWidth: 1.5))
                }
            }
            Button(action: onDismiss) {
                Text("Keep going")
                    .font(.app(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.primaryGreen))
            }
        }
    }

    // MARK: Sequence

    private func play() {
        renderShareImage()
        guard !reduceMotion else {
            stamped = true; shockwave = true; showDetails = true; showActions = true
            streakShown = Double(info.streak)
            CoinHaptics.seal()
            SoundEffects.play(.clink)
            return
        }
        withAnimation(.spring(duration: 0.34, bounce: 0.28)) { stamped = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            CoinHaptics.seal()
            SoundEffects.play(.clink)
            withAnimation(.easeOut(duration: 0.75)) { shockwave = true }
            confetti += 1
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.55)) { streakShown = Double(info.streak) }
        withAnimation(.spring(duration: 0.45, bounce: 0.35).delay(0.9)) { showDetails = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { Beat.pop() }
        withAnimation(.easeOut(duration: 0.4).delay(1.4)) { showActions = true }
    }

    @MainActor private func renderShareImage() {
        let card = DaySealedStoryCard(streak: info.streak, totalDays: info.totalNoSpendDays, date: today)
            .frame(width: 360, height: 640)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}

// MARK: - Pieces

struct RewardChip: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.app(size: 12, weight: .bold))
            Text(text).font(.app(size: 13, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
    }
}

/// Segmented track from the last milestone to the next; one pip per day when it fits.
struct MilestoneTrack: View {
    let from: Int
    let to: Int
    let current: Int

    var body: some View {
        let span = max(1, to - from)
        let done = min(span, max(0, current - from))
        GeometryReader { geo in
            if span <= 16 {
                HStack(spacing: 4) {
                    ForEach(0..<span, id: \.self) { i in
                        Capsule()
                            .fill(i < done ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(AppTheme.cardBackgroundLight))
                            .overlay(i == done - 1 ? Capsule().stroke(.white.opacity(0.7), lineWidth: 1) : nil)
                    }
                }
            } else {
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.cardBackgroundLight)
                    Capsule().fill(AppTheme.primaryGradient)
                        .frame(width: geo.size.width * CGFloat(done) / CGFloat(span))
                }
            }
        }
        .accessibilityLabel(String(localized: "\(current) of \(to) days"))
    }
}

/// Wraps chips onto as many rows as needed; rows are centred unless `alignment` is `.leading`.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .center

    private func rows(_ subviews: Subviews, maxWidth: CGFloat) -> [[(Int, CGSize)]] {
        var rows: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            if x + s.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([]); x = 0
            }
            rows[rows.count - 1].append((i, s))
            x += s.width + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        let rs = rows(subviews, maxWidth: maxW)
        let h = rs.reduce(0) { $0 + ($1.map(\.1.height).max() ?? 0) } + spacing * CGFloat(max(0, rs.count - 1))
        let w = rs.map { r in r.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, r.count - 1)) }.max() ?? 0
        return CGSize(width: min(w, maxW), height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, maxWidth: bounds.width) {
            let rowW = row.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, row.count - 1))
            let rowH = row.map(\.1.height).max() ?? 0
            var x = alignment == .leading ? bounds.minX : bounds.minX + (bounds.width - rowW) / 2
            for (i, s) in row {
                subviews[i].place(at: CGPoint(x: x, y: y + (rowH - s.height) / 2), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += rowH + spacing
        }
    }
}

/// 9:16 image shared to stories. Contains no amounts or personal data beyond the streak.
struct DaySealedStoryCard: View {
    let streak: Int
    let totalDays: Int
    let date: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "04140D"), Color(hex: "0A2A1C"), Color(hex: "04140D")],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [AppTheme.accentGold.opacity(0.28), .clear],
                           center: UnitPoint(x: 0.5, y: 0.38), startRadius: 10, endRadius: 260)
            VStack(spacing: 18) {
                Spacer()
                SealMedallion(caption: date).frame(width: 220, height: 220)
                Text("\(streak)")
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, AppTheme.accentGold], startPoint: .top, endPoint: .bottom))
                Text(streak == 1 ? String(localized: "day without spending") : String(localized: "days in a row without spending"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                if totalDays > streak {
                    Text(String(localized: "\(totalDays) no-spend days total"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primaryGreen)
                }
                Spacer()
                HStack(spacing: 8) {
                    Image("BrandIcon").resizable().frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 7))
                    Text("SpendZero · No Spend Challenge")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.bottom, 36)
            }
        }
    }
}
