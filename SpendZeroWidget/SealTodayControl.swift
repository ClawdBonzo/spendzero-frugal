import SwiftUI
import WidgetKit
import AppIntents

/// "Seal today" for Control Center, the Lock Screen control slots and the Action button.
/// Shows whether today is already sealed; tapping runs `SealTodayIntent` in the app's process.
struct SealTodayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SealTodayControlKind.kind, provider: Provider()) { status in
            ControlWidgetButton(action: SealTodayIntent()) {
                switch status {
                case .sealed:
                    Label("Sealed", systemImage: "checkmark.seal.fill")
                case .spent:
                    Label("Spent Today", systemImage: "xmark.seal")
                case .open:
                    Label("Seal Today", systemImage: "seal")
                }
            } actionLabel: { isActive in
                if isActive {
                    Label("Sealing…", systemImage: "seal.fill")
                }
            }
            .tint(status == .spent ? WidgetPalette.red : (status == .sealed ? WidgetPalette.green : WidgetPalette.gold))
        }
        .displayName("Seal Today")
        .description("Seal today as a no-spend day without opening SpendZero.")
    }

    enum Status { case open, sealed, spent }

    struct Provider: ControlValueProvider {
        var previewValue: Status { .open }

        func currentValue() async throws -> Status {
            if SealStatus.isSealed() { return .sealed }
            return SealStatus.isBlocked() ? .spent : .open
        }
    }
}
