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
    /// Parse a user-typed money amount in the given locale ("12,50" in de_DE, "12.50" in en_US).
    /// Accepts a "." fallback for locales whose decimal pad still produces a dot. Returns nil for
    /// empty, non-numeric, zero, or negative input.
    static func parseAmount(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.isLenient = true
        var value = f.number(from: trimmed)?.doubleValue
        if value == nil, trimmed.filter({ $0 == "." || $0 == "," }).count == 1 {
            // Single separator of the "wrong" kind for this locale: treat it as the decimal point.
            let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
            value = Double(normalized)
        }
        guard let v = value, v.isFinite, v > 0 else { return nil }
        return (v * 100).rounded() / 100
    }

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
