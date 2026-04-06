import SwiftUI
import SwiftData
import PDFKit

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \SavingsEntry.date, order: .reverse) private var savings: [SavingsEntry]
    @Query(sort: \SpendingLog.date, order: .reverse) private var spending: [SpendingLog]
    @Query(sort: \ImpulseLog.date, order: .reverse) private var impulses: [ImpulseLog]
    @Query(sort: \DailyRecord.date, order: .reverse) private var records: [DailyRecord]
    @State private var isGenerating = false
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var selectedRange: ExportRange = .month

    enum ExportRange: String, CaseIterable {
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case all = "All Time"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                // Preview card
                VStack(spacing: 16) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.primaryGradient)

                    Text("Savings Report")
                        .font(AppTheme.titleFont)
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Generate a beautiful PDF report\nof your financial progress")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Range picker
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(ExportRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                // Stats preview
                VStack(spacing: 12) {
                    ExportPreviewRow(title: "Total Saved", value: "$\(Int(filteredSavingsTotal))", icon: "dollarsign.circle.fill", color: AppTheme.primaryGreen)
                    ExportPreviewRow(title: "Total Spent", value: "$\(Int(filteredSpendingTotal))", icon: "cart.fill", color: AppTheme.destructive)
                    ExportPreviewRow(title: "No-Spend Days", value: "\(filteredNoSpendDays)", icon: "checkmark.seal.fill", color: AppTheme.primaryGreen)
                    ExportPreviewRow(title: "Impulses Resisted", value: "\(filteredImpulsesResisted)", icon: "bolt.slash.fill", color: AppTheme.info)
                }
                .padding(AppTheme.paddingMedium)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .fill(AppTheme.cardBackground)
                )

                Spacer()

                // Generate button
                PrimaryButton(
                    title: isGenerating ? "Generating..." : "Generate PDF Report",
                    icon: "doc.fill"
                ) {
                    generatePDF()
                }
                .disabled(isGenerating)

                if pdfURL != nil {
                    SecondaryButton(title: "Share Report", icon: "square.and.arrow.up") {
                        showShareSheet = true
                    }
                }
            }
            .padding(.horizontal, AppTheme.paddingMedium)
            .padding(.top, 20)
        }
        .navigationTitle("Export Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL {
                ShareSheet(activityItems: [pdfURL])
            }
        }
    }

    // MARK: - Filtered Data

    private var cutoffDate: Date? {
        guard let days = selectedRange.days else { return nil }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())
    }

    private var filteredSavingsTotal: Double {
        let filtered = cutoffDate.map { cutoff in savings.filter { $0.date >= cutoff } } ?? savings
        return filtered.reduce(0) { $0 + $1.amount }
    }

    private var filteredSpendingTotal: Double {
        let filtered = cutoffDate.map { cutoff in spending.filter { $0.date >= cutoff } } ?? spending
        return filtered.reduce(0) { $0 + $1.amount }
    }

    private var filteredNoSpendDays: Int {
        let filtered = cutoffDate.map { cutoff in records.filter { $0.date >= cutoff } } ?? records
        return filtered.filter(\.isNoSpendDay).count
    }

    private var filteredImpulsesResisted: Int {
        let filtered = cutoffDate.map { cutoff in impulses.filter { $0.date >= cutoff } } ?? impulses
        return filtered.filter(\.wasResisted).count
    }

    // MARK: - PDF Generation

    private func generatePDF() {
        isGenerating = true

        let profile = profiles.first
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            var yOffset: CGFloat = margin

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let title = "SpendZero Savings Report"
            title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttrs)
            yOffset += 40

            // Subtitle
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateStr = "Generated \(Date().formatted(date: .abbreviated, time: .shortened))"
            dateStr.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: subtitleAttrs)
            yOffset += 30

            if let name = profile?.displayName {
                "Prepared for: \(name)".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: subtitleAttrs)
                yOffset += 40
            }

            // Stats
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]

            "Summary (\(selectedRange.rawValue))".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: headerAttrs)
            yOffset += 30

            let stats = [
                "Total Saved: $\(Int(filteredSavingsTotal))",
                "Total Spent: $\(Int(filteredSpendingTotal))",
                "Net Savings: $\(Int(filteredSavingsTotal - filteredSpendingTotal))",
                "No-Spend Days: \(filteredNoSpendDays)",
                "Impulses Resisted: \(filteredImpulsesResisted)",
                "Current Streak: \(profile?.currentStreak ?? 0) days",
                "Longest Streak: \(profile?.longestStreak ?? 0) days"
            ]

            for stat in stats {
                stat.draw(at: CGPoint(x: margin + 10, y: yOffset), withAttributes: bodyAttrs)
                yOffset += 22
            }

            yOffset += 20

            // Top spending categories
            "Top Spending Categories".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: headerAttrs)
            yOffset += 30

            let filteredSpending = cutoffDate.map { cutoff in spending.filter { $0.date >= cutoff } } ?? spending
            let categoryTotals = Dictionary(grouping: filteredSpending, by: \.category)
                .map { (category: $0.key.rawValue, total: $0.value.reduce(0) { $0 + $1.amount }) }
                .sorted { $0.total > $1.total }
                .prefix(5)

            for item in categoryTotals {
                "\(item.category): $\(Int(item.total))".draw(at: CGPoint(x: margin + 10, y: yOffset), withAttributes: bodyAttrs)
                yOffset += 22
            }

            if categoryTotals.isEmpty {
                "No spending data for this period".draw(at: CGPoint(x: margin + 10, y: yOffset), withAttributes: subtitleAttrs)
            }

            // Footer
            let footerY = pageHeight - margin
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            "SpendZero - Your data stays on your device. Always private.".draw(at: CGPoint(x: margin, y: footerY), withAttributes: footerAttrs)
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("SpendZero_Report_\(Date().formatted(date: .numeric, time: .omitted)).pdf")
        try? data.write(to: tempURL)
        pdfURL = tempURL
        isGenerating = false
    }
}

struct ExportPreviewRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
