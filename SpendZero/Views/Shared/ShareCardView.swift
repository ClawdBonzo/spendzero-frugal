import SwiftUI

// MARK: - Streak Share Card
// Renders a 380×280 pt shareable card, captured via ImageRenderer at 3× scale
// and shared through the system share sheet (UIActivityViewController).

struct StreakShareCard: View {
    let streak: Int
    let name: String
    let totalSaved: Double

    var body: some View {
        ZStack {
            // Deep green background
            LinearGradient(
                colors: [Color(hex: "071207"), Color(hex: "0D2B1A"), Color(hex: "071207")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient circles
            Circle()
                .fill(AppTheme.primaryGreen.opacity(0.07))
                .frame(width: 300, height: 300)
                .offset(x: -90, y: -90)
            Circle()
                .fill(AppTheme.accentGold.opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: 110, y: 110)

            // Border gradient ring
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.primaryGreen.opacity(0.5), AppTheme.accentGold.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 8) {
                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("SpendZero")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("No-Spend Challenge")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.primaryGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.primaryGreen.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                // Hero streak number
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 44))
                    Text("\(streak)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accentGold, Color(hex: "FF7043")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                .padding(.bottom, 4)

                Text("day\(streak == 1 ? "" : "s") no-spend streak")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))

                if !name.isEmpty {
                    Text("\(name) is crushing it 💪")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.top, 2)
                }

                Spacer()

                // Stats row
                HStack(spacing: 16) {
                    if totalSaved > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(totalSaved.currencyFormatted)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primaryGreen)
                            Text("saved")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }

                    Spacer()

                    Text("Download SpendZero →")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.primaryGreen.opacity(0.8))
                }
            }
            .padding(22)
        }
        .frame(width: 380, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Share Button

struct ShareStreakButton: View {
    let streak: Int
    let name: String
    let totalSaved: Double

    @State private var isRendering = false
    @State private var shareItems: [Any] = []
    @State private var showSheet = false

    var body: some View {
        Button {
            renderAndShare()
        } label: {
            HStack(spacing: 6) {
                if isRendering {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(AppTheme.primaryGreen)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text("Share")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(AppTheme.primaryGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.primaryGreen.opacity(0.12))
            .clipShape(Capsule())
        }
        .disabled(isRendering)
        .sheet(isPresented: $showSheet) {
            ShareSheetView(items: shareItems)
                .presentationDetents([.medium, .large])
        }
        .accessibilityLabel("Share your \(streak)-day streak")
    }

    private func renderAndShare() {
        isRendering = true
        // ImageRenderer must be created and used on the MainActor (Swift 6 compliant)
        Task { @MainActor in
            let card = StreakShareCard(streak: streak, name: name, totalSaved: totalSaved)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3.0 // @3x for crisp sharing
            if let uiImage = renderer.uiImage {
                shareItems = [uiImage]
                showSheet = true
            }
            isRendering = false
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
