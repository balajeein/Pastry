import Foundation

public enum CalculatorFormatter {
    public static func format(_ value: Double) -> String? {
        guard !value.isNaN && !value.isInfinite else { return nil }
        
        let val = abs(value) < 1e-12 ? 0.0 : value
        
        let rounded = round(val)
        let effectiveValue: Double
        if abs(val - rounded) < 1e-11 {
            effectiveValue = rounded
        } else {
            effectiveValue = val
        }
        
        let absVal = abs(effectiveValue)
        
        let locale = Locale(identifier: "en_US_POSIX")
        
        if absVal > 0 && (absVal >= 1e12 || absVal < 1e-5) {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = 8
            formatter.exponentSymbol = "e"
            if let str = formatter.string(from: NSNumber(value: effectiveValue)) {
                return str.replacingOccurrences(of: "e+", with: "e")
            }
        }
        
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 10
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        
        return formatter.string(from: NSNumber(value: effectiveValue))
    }
}
