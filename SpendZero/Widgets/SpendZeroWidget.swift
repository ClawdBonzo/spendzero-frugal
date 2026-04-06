import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Timeline Provider

struct SavingsProvider: TimelineProvider {
    func placeholder(in context: Context) -> SavingsWidgetEntry {
        SavingsWidgetEntry(date: Date(), totalSaved: 847, currentStreak: 12, isNoSpendDay: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SavingsWidgetEntry) -> Void) {
        let entry = SavingsWidgetEntry(date: Date(), totalSaved: 847, currentStreak: 12, isNoSpendDay: true)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavingsWidgetEntry>) -> Void) {
        // In production, read from shared App Group container
        let entry = SavingsWidgetEntry(date: Date(), totalSaved: 0, currentStreak: 0, isNoSpendDay: true)
        let timeline = Timeline(entries: [entry], policy: .after(Calendar.current.date(byAdding: .hour, value: 1, to: Date())!))
        completion(timeline)
    }

    typealias Entry = SavingsWidgetEntry
}

struct SavingsWidgetEntry: TimelineEntry {
    let date: Date
    let totalSaved: Double
    let currentStreak: Int
    let isNoSpendDay: Bool
}

// MARK: - Widget Views

struct SavingsWidgetView: View {
    var entry: SavingsWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("BrandIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("SpendZero")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("$\(Int(entry.totalSaved))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "00E676"))

            Text("Total Saved")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "FFD740"))
                Text("\(entry.currentStreak) day streak")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    Text("SpendZero")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("$\(Int(entry.totalSaved))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "00E676"))

                Text("Total Saved")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color(hex: "FFD740"))
                    VStack(alignment: .leading) {
                        Text("\(entry.currentStreak)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Day Streak")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: entry.isNoSpendDay ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(entry.isNoSpendDay ? Color(hex: "00E676") : Color(hex: "FF5252"))
                    VStack(alignment: .leading) {
                        Text(entry.isNoSpendDay ? "On Track" : "Spent")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Today")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configuration

struct SpendZeroSavingsWidget: Widget {
    let kind = "SpendZeroSavingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SavingsProvider()) { entry in
            SavingsWidgetView(entry: entry)
        }
        .configurationDisplayName("Savings Glance")
        .description("See your total savings and current streak at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
