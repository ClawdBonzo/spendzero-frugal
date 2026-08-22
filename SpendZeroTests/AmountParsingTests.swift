import Testing
import Foundation
@testable import SpendZero

struct AmountParsingTests {
    @Test func parsesDotAndCommaDecimals() {
        #expect(Double.parseAmount("12.50", locale: Locale(identifier: "en_US")) == 12.5)
        #expect(Double.parseAmount("12,50", locale: Locale(identifier: "de_DE")) == 12.5)
        #expect(Double.parseAmount("1.234,56", locale: Locale(identifier: "de_DE")) == 1234.56)
    }

    @Test func rejectsNegativeZeroAndGarbage() {
        #expect(Double.parseAmount("-5", locale: Locale(identifier: "en_US")) == nil)
        #expect(Double.parseAmount("0", locale: Locale(identifier: "en_US")) == nil)
        #expect(Double.parseAmount("abc", locale: Locale(identifier: "en_US")) == nil)
        #expect(Double.parseAmount("", locale: Locale(identifier: "en_US")) == nil)
    }
}
