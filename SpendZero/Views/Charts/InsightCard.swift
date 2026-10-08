import SwiftUI
import Charts

/// The card chrome every Progress chart sits in: title, optional trailing accessory, content.
struct InsightCard<Content: View, Accessory: View>: View {
    let title: Text
    var subtitle: Text?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(_ title: Text, subtitle: Text? = nil,
         @ViewBuilder accessory: () -> Accessory = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    title
                        .font(.app(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        subtitle
                            .font(.app(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                accessory
            }
            content
        }
        .padding(AppTheme.paddingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.07), .clear],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1)
                )
        )
    }
}

/// Friendly empty state used inside chart cards.
struct ChartEmptyState: View {
    let icon: String
    let title: Text
    let message: Text

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.app(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.primaryGreen.opacity(0.55))
                .symbolRenderingMode(.hierarchical)
            title
                .font(.app(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            message
                .font(.app(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }
}

/// VoiceOver audio-graph descriptor for a single date/value series.
struct DateValueChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let seriesName: String
    let points: [(Date, Double)]
    var categorical = false

    func makeChartDescriptor() -> AXChartDescriptor {
        let values = points.map(\.1)
        let lo = values.min() ?? 0, hi = max(values.max() ?? 1, lo + 1)
        let dateFormat = Date.FormatStyle.dateTime.month(.abbreviated).day()
        let x: any AXDataAxisDescriptor = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Date"),
            categoryOrder: points.map { $0.0.formatted(dateFormat) })
        let y = AXNumericDataAxisDescriptor(title: seriesName, range: lo...hi, gridlinePositions: []) {
            $0.currencyFormatted
        }
        let series = AXDataSeriesDescriptor(name: seriesName, isContinuous: !categorical,
                                            dataPoints: points.map { .init(x: $0.0.formatted(dateFormat), y: $0.1) })
        return AXChartDescriptor(title: title, summary: summary, xAxis: x, yAxis: y, additionalAxes: [], series: [series])
    }
}
