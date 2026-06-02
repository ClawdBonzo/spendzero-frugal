import Foundation

// MARK: - Cached Formatters
// NumberFormatter init is expensive (loads locale/ICU data). These values render
// in tight loops (chart axes, calendar cells, stat cards), so we cache shared
// instances instead of allocating one per call. Access is on the main actor, so
// a shared mutable formatter is safe here.
private enum SharedFormatters {
    static let currency0: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    static let currency2: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f
    }()

    static let ordinal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()
}

extension Double {
    var currencyFormatted: String {
        SharedFormatters.currency0.string(from: NSNumber(value: self)) ?? "$0"
    }

    var currencyFormattedDecimal: String {
        SharedFormatters.currency2.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var percentFormatted: String {
        "\(Int(self * 100))%"
    }
}

extension Locale {
    /// The device locale's currency symbol (€, £, R$, ₹, $…), falling back to "$".
    static var displayCurrencySymbol: String { Locale.current.currencySymbol ?? "$" }
}

extension Int {
    var ordinal: String {
        SharedFormatters.ordinal.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
