import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

/// Evening check-in Live Activity: countdown to midnight, current streak, and a Seal button.
struct SealTodayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SealTodayAttributes.self) { context in
            SealTodayLockScreenView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(WidgetPalette.background.opacity(0.92))
                .activitySystemActionForegroundColor(WidgetPalette.gold)
        } dynamicIsland: { context in
            let state = context.state
            let closed = context.isStale || state.deadline <= Date()
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        GoldCoin(streak: state.streak, sealed: state.sealed, size: 44)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(state.streak)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(WidgetPalette.gold)
                                .contentTransition(.numericText(value: Double(state.streak)))
                            Text("day streak")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        CountdownText(state: state, closed: closed)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(state.sealed ? WidgetPalette.green : WidgetPalette.gold)
                        Text(state.sealed ? "sealed" : "left today")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if state.sealed {
                            Label("Today is sealed. See you tomorrow.", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(WidgetPalette.green)
                            Spacer(minLength: 0)
                        } else if closed {
                            Text("Day closed")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer(minLength: 0)
                        } else {
                            ProgressView(timerInterval: state.windowStart...max(state.windowStart, state.deadline),
                                         countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                                .tint(WidgetPalette.gold)
                            SealButton()
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: state.sealed ? "checkmark.seal.fill" : "flame.fill")
                        .foregroundStyle(state.sealed ? WidgetPalette.green : WidgetPalette.gold)
                    Text("\(state.streak)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.gold)
                }
            } compactTrailing: {
                if state.sealed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WidgetPalette.green)
                } else {
                    CountdownText(state: state, closed: closed)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetPalette.gold)
                        .frame(maxWidth: 52)
                }
            } minimal: {
                Image(systemName: state.sealed ? "checkmark.seal.fill" : "flame.fill")
                    .foregroundStyle(state.sealed ? WidgetPalette.green : WidgetPalette.gold)
            }
            .keylineTint(WidgetPalette.gold)
        }
    }
}

/// Countdown to midnight. `Text(timerInterval:)` ticks on its own without activity updates.
private struct CountdownText: View {
    let state: SealTodayAttributes.ContentState
    let closed: Bool

    var body: some View {
        if state.sealed {
            Text("✓")
        } else if closed {
            Text("0:00")
        } else {
            Text(timerInterval: Date()...max(Date(), state.deadline), countsDown: true, showsHours: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SealButton: View {
    var body: some View {
        Button(intent: SealTodayIntent()) {
            Label("Seal", systemImage: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(WidgetPalette.goldInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(WidgetPalette.goldFace, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Lock Screen / banner presentation.
struct SealTodayLockScreenView: View {
    let state: SealTodayAttributes.ContentState
    let isStale: Bool

    private var closed: Bool { isStale || state.deadline <= Date() }

    var body: some View {
        HStack(spacing: 14) {
            GoldCoin(streak: state.streak, sealed: state.sealed, size: 58)

            VStack(alignment: .leading, spacing: 4) {
                if state.sealed {
                    Text("Today is sealed")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.green)
                    Text("\(state.streak)-day streak. See you tomorrow.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                } else if closed {
                    Text("Day closed")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Open SpendZero to check in.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        CountdownText(state: state, closed: closed)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(WidgetPalette.gold)
                            .fixedSize()
                        Text("left to seal today")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    ProgressView(timerInterval: state.windowStart...max(state.windowStart, state.deadline),
                                 countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(WidgetPalette.gold)
                    Text("\(state.streak)-day streak on the line")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if !state.sealed && !closed {
                Spacer(minLength: 0)
                SealButton()
            }
        }
        .padding(16)
    }
}

#if DEBUG
#Preview("Lock Screen", as: .content, using: SealTodayAttributes(day: Calendar.current.startOfDay(for: Date()))) {
    SealTodayLiveActivity()
} contentStates: {
    SealTodayAttributes.ContentState(streak: 12, windowStart: Date(), deadline: Date().addingTimeInterval(3 * 3600), sealed: false)
    SealTodayAttributes.ContentState(streak: 13, windowStart: Date(), deadline: Date().addingTimeInterval(3 * 3600), sealed: true)
}
#endif
