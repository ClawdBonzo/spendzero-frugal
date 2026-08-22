import Foundation

/// A small daily win the user can check off. `title` is the stable identifier persisted in
/// `DailyRecord.wins`; `label` is what's shown.
struct WinItem {
    let icon: String
    let title: String
    let savedAmount: Double
    var saved: String { savedAmount.currencyFormatted }
    var label: String { String(localized: String.LocalizationValue(title)) }

    static let all: [WinItem] = [
        WinItem(icon: "cup.and.saucer.fill", title: "Made coffee at home", savedAmount: 5),
        WinItem(icon: "fork.knife", title: "Packed lunch", savedAmount: 12),
        WinItem(icon: "figure.walk", title: "Walked instead of Uber", savedAmount: 15),
        WinItem(icon: "tv.fill", title: "Free entertainment", savedAmount: 15),
        WinItem(icon: "bag.fill", title: "Skipped online shopping", savedAmount: 30)
    ]
}
